import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_services.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../models/playable_media.dart';
import '../models/subtitle.dart';
import '../services/subtitle_service.dart';
import '../widgets/poster.dart';
import 'source_selectors.dart';
import 'srt_parser.dart';

/// Écran de lecture vidéo (chewie + video_player).
///
/// - Lecture / pause, seek, plein écran : assurés par chewie.
/// - Qualité : choix parmi les [StreamSource] du média (1080p / 720p /
///   480p / Source) ; la position est conservée au changement.
/// - Sous-titres .srt : ceux du flux (souvent le .srt Archive.org) sont
///   chargés automatiquement ; choix via le menu (⋮) du lecteur.
/// - Reprise : la position est sauvegardée (toutes les 5 s, à la pause et
///   à la fermeture) via [AppServices.library] et restaurée au prochain
///   lancement (« Continuer à regarder »).
/// - Fichier téléchargé : lu en priorité quand il existe (hors-ligne).
///
/// SOURCES LÉGALES UNIQUEMENT : les sources viennent de [StreamSource]
/// (Archive.org / serveur personnel). TMDB ne fournit que des métadonnées.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.media,
    this.localFilePath,
    this.subtitleService,
  });

  /// Média à lire (élément + sources légales).
  final PlayableMedia media;

  /// Chemin du fichier téléchargé (lecture hors-ligne prioritaire).
  final String? localFilePath;

  /// Service sous-titres (un nouveau est créé si non fourni).
  final SubtitleService? subtitleService;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  StreamSource? _offlineSource;
  late StreamSource _currentSource;
  bool _usingLocalFile = false;
  List<Subtitle> _subtitles = [];
  String? _subtitleLabel;
  bool _subtitlesOff = false;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastSave;
  double _savedFraction = 0.0;
  late final SubtitleService _subtitleService;
  bool _ownsSubtitleService = false;

  @override
  void initState() {
    super.initState();
    _subtitleService = widget.subtitleService ?? SubtitleService();
    _ownsSubtitleService = widget.subtitleService == null;
    if (widget.localFilePath != null) {
      _offlineSource = StreamSource(
        url: widget.localFilePath!,
        quality: StreamQuality.source,
        format: 'mp4',
        source: 'Fichier téléchargé',
      );
    }
    _resolveAndInit();
  }

  /// Choisit la source de départ et la position de reprise, puis initialise.
  Future<void> _resolveAndInit() async {
    // 1. Source de départ : fichier hors-ligne en priorité, sinon la
    //    source initiale demandée, sinon la meilleure disponible.
    StreamSource? initial;
    if (_offlineSource != null) {
      initial = _offlineSource;
      _usingLocalFile = true;
    } else if (widget.media.initialSource != null) {
      initial = widget.media.initialSource;
    } else if (widget.media.sources.isNotEmpty) {
      initial = widget.media.sources.first;
    }
    if (initial == null) {
      setState(() {
        _isLoading = false;
        _error = 'Aucune source vidéo légale pour ce titre.\n'
            'TMDB ne fournit que des métadonnées ; seuls les films du '
            'domaine public (Archive.org) sont lisibles ici.';
      });
      return;
    }
    _currentSource = initial;

    // 2. Position de reprise (« Continuer à regarder »).
    try {
      final entries = await AppServices.library.continueWatching();
      for (final entry in entries) {
        if (entry.item.id == widget.media.item.id) {
          _savedFraction = entry.progress;
          break;
        }
      }
    } catch (_) {
      // Sans historique, la lecture commence au début.
    }
    await _initializeSource(_currentSource);
  }

  /// Toutes les sources proposées (fichier hors-ligne en premier).
  List<StreamSource> get _availableSources {
    final list = <StreamSource>[];
    if (_offlineSource != null) list.add(_offlineSource!);
    list.addAll(widget.media.sources);
    return list;
  }

  bool _isLocalSource(StreamSource source) =>
      !source.url.startsWith('http');

  String _labelFor(StreamSource source) =>
      _isLocalSource(source) ? 'Hors-ligne' : source.qualityLabel;

  /// (Ré)initialise les contrôleurs pour une source donnée.
  Future<void> _initializeSource(StreamSource source,
      {Duration? startAt}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    // Sortir du plein écran avant de reconstruire les contrôleurs.
    if (_chewieController?.isFullScreen == true) {
      _chewieController!.exitFullScreen();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await _disposeControllers();

    final isLocal = _isLocalSource(source);
    final controller = isLocal
        ? VideoPlayerController.file(File(source.url))
        : VideoPlayerController.networkUrl(Uri.parse(source.url));
    _videoController = controller;

    try {
      await controller.initialize();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de lire cette source. Essaie une autre qualité.';
      });
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }

    // Sous-titres : ceux du flux sont chargés automatiquement, sauf si
    // l'utilisateur a choisi « Aucun ».
    if (!_subtitlesOff && source.subtitleUrl != null) {
      await _loadSubtitlesFromUrl(source.subtitleUrl!, rebuild: false);
    }

    // Reprise de lecture : position explicite (changement de qualité) ou
    // position sauvegardée (fraction x durée). On ne reprend que si la
    // position est significative et pas dans les 5 derniers %.
    final duration = controller.value.duration;
    var resume = startAt ?? Duration.zero;
    if (startAt == null && _savedFraction > 0.02 && duration > Duration.zero) {
      resume = Duration(
        milliseconds: (duration.inMilliseconds * _savedFraction).round(),
      );
    }
    if (resume > const Duration(seconds: 5) &&
        (duration == Duration.zero ||
            resume.inMilliseconds < duration.inMilliseconds * 0.95)) {
      await controller.seekTo(resume);
    }
    _savedFraction = 0.0;

    _chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppTheme.gold,
        handleColor: AppTheme.gold,
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white38,
      ),
      placeholder: PosterArt(item: widget.media.item, borderRadius: 0),
      subtitle: _subtitles.isEmpty ? null : Subtitles(_subtitles),
      errorBuilder: (context, errorMessage) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Erreur de lecture : $errorMessage',
            style: const TextStyle(color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      additionalOptions: (context) => [
        if (_availableSources.length > 1)
          OptionItem(
            iconData: Icons.high_quality,
            title: 'Qualité : ${_labelFor(_currentSource)}',
            onTap: () => _showQualitySheet(context),
          ),
        if (_subtitleTracks.isNotEmpty)
          OptionItem(
            iconData: Icons.subtitles,
            title: 'Sous-titres : ${_subtitleLabel ?? 'Aucun'}',
            onTap: () => _showSubtitleSheet(context),
          ),
      ],
    );
    controller.addListener(_onVideoUpdate);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  /// Pistes de sous-titres disponibles (dédupliquées par URL).
  List<SubtitleFile> get _subtitleTracks {
    final seen = <String>{};
    final tracks = <SubtitleFile>[];
    for (final source in widget.media.sources) {
      final url = source.subtitleUrl;
      if (url != null && seen.add(url)) {
        tracks.add(SubtitleFile.fromDirectUrl(
          url,
          language: url.toLowerCase().contains('.fr.') ? 'fr' : 'en',
        ));
      }
    }
    return tracks;
  }

  /// Sauvegarde la position toutes les 5 s de lecture.
  void _onVideoUpdate() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final now = DateTime.now();
    if (_lastSave == null || now.difference(_lastSave!).inSeconds >= 5) {
      _lastSave = now;
      unawaited(_saveProgress());
    }
  }

  Future<void> _saveProgress() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration == Duration.zero) return;
    final progress =
        (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    try {
      await AppServices.library.recordProgress(
        widget.media.item,
        progress,
        _remainingLabel(position, duration),
      );
    } catch (_) {
      // Stockage indisponible : la reprise est simplement perdue.
    }
  }

  String _remainingLabel(Duration position, Duration duration) {
    final remaining = duration - position;
    if (remaining <= Duration.zero) return 'Terminé';
    if (remaining.inHours > 0) {
      return '${remaining.inHours} h ${remaining.inMinutes % 60} min restantes';
    }
    if (remaining.inMinutes <= 0) return 'Moins d’une minute restante';
    return '${remaining.inMinutes} min restantes';
  }

  /// Change de source (qualité / hors-ligne) en gardant la position.
  Future<void> _switchSource(StreamSource source) async {
    if (source.url == _currentSource.url) return;
    final position = _videoController?.value.position ?? Duration.zero;
    _currentSource = source;
    _usingLocalFile = _isLocalSource(source);
    await _initializeSource(source, startAt: position);
  }

  Future<void> _showQualitySheet(BuildContext context) async {
    final chosen = await QualitySelectorSheet.show(
      context,
      sources: _availableSources,
      current: _currentSource,
      labelFor: _labelFor,
    );
    if (chosen != null) await _switchSource(chosen);
  }

  Future<void> _showSubtitleSheet(BuildContext context) async {
    final selection = await SubtitleSelectorSheet.show(
      context,
      tracks: _subtitleTracks,
      currentLabel: _subtitleLabel,
    );
    if (selection == null) return; // feuille fermée sans choix
    final file = selection.file;
    if (file == null || file.downloadUrl == null) {
      await _clearSubtitles();
    } else {
      await _loadSubtitlesFromUrl(file.downloadUrl!);
    }
  }

  /// Charge un .srt depuis une URL puis reconstruit le lecteur.
  Future<void> _loadSubtitlesFromUrl(String url,
      {bool rebuild = true}) async {
    try {
      final text = await _subtitleService.fetchSrtText(url);
      _subtitles = SrtParser.parse(text);
      _subtitleLabel = url.toLowerCase().contains('.fr.')
          ? 'Français'
          : 'Sous-titres';
      _subtitlesOff = false;
      if (rebuild && _videoController != null) {
        final position = _videoController!.value.position;
        await _initializeSource(_currentSource, startAt: position);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Impossible de charger ces sous-titres.')),
        );
      }
    }
  }

  Future<void> _clearSubtitles() async {
    _subtitles = [];
    _subtitleLabel = null;
    _subtitlesOff = true;
    if (_videoController != null) {
      final position = _videoController!.value.position;
      await _initializeSource(_currentSource, startAt: position);
    }
  }

  /// Épisode lu (pour le téléchargement), null pour un film.
  Episode? get _episode {
    final number = widget.media.episodeNumber;
    if (number == null) return null;
    return Episode(
      number: number,
      title: 'Épisode $number',
      durationMinutes: 0,
      seasonNumber: widget.media.seasonNumber,
    );
  }

  /// Télécharge la source en cours (légale uniquement, voir DownloadManager).
  Future<void> _downloadCurrentSource() async {
    if (_usingLocalFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce fichier est déjà téléchargé.')),
      );
      return;
    }
    try {
      await AppServices.downloads.start(
        _currentSource,
        item: widget.media.item,
        episode: _episode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Téléchargement lancé — voir l’onglet Téléchargements.'),
          ),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _disposeControllers() async {
    _videoController?.removeListener(_onVideoUpdate);
    await _chewieController?.dispose();
    _chewieController = null;
    await _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    // Sauvegarde finale (position capturée avant la fermeture).
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      final position = controller.value.position;
      final duration = controller.value.duration;
      if (duration > Duration.zero) {
        final progress =
            (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0);
        unawaited(AppServices.library.recordProgress(
          widget.media.item,
          progress,
          _remainingLabel(position, duration),
        ));
      }
    }
    _videoController?.removeListener(_onVideoUpdate);
    unawaited(_chewieController?.dispose());
    unawaited(_videoController?.dispose());
    if (_ownsSubtitleService) _subtitleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episodeNumber = widget.media.episodeNumber;
    final title = episodeNumber == null
        ? widget.media.item.title
        : '${widget.media.item.title} — Épisode $episodeNumber';
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Télécharger',
            onPressed: _isLoading ? null : _downloadCurrentSource,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  unawaited(_resolveAndInit());
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }
    if (_isLoading || _chewieController == null || _videoController == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.gold));
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
