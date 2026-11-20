import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/legal_sources.dart';
import '../models/models.dart';
import '../models/playable_media.dart';
import '../services/download_service.dart';
import '../services/server_config_service.dart';
import '../services/subtitle_service.dart';
import 'video_player_screen.dart';

/// Implémentation réelle du lecteur (contrat [PlayerService]).
///
/// `play()` reçoit une source déjà résolue (voir `media_actions.dart`) :
/// la liste complète est récupérée pour le choix de qualité, et le
/// fichier téléchargé est lu en priorité quand il existe.
///
/// Navigation : le service pousse [PlayerScreen] via une clé de
/// navigation. `main.dart` doit brancher cette clé sur MaterialApp :
/// ```dart
/// MaterialApp(
///   navigatorKey: VideoPlayerService.navigatorKey,
///   ...
/// )
/// ```
/// Sans elle, [play] lève un [StateError] explicite.
class VideoPlayerService implements PlayerService {
  VideoPlayerService({
    GlobalKey<NavigatorState>? navigatorKey,
    SubtitleService? subtitleService,
  })  : _navigatorKey = navigatorKey ?? _defaultNavigatorKey,
        _subtitleService = subtitleService ?? SubtitleService();

  /// Clé de navigation à brancher sur MaterialApp (voir doc ci-dessus).
  static final GlobalKey<NavigatorState> _defaultNavigatorKey =
      GlobalKey<NavigatorState>();

  static GlobalKey<NavigatorState> get navigatorKey => _defaultNavigatorKey;

  final GlobalKey<NavigatorState> _navigatorKey;
  final SubtitleService _subtitleService;

  @override
  Future<void> play(StreamSource source,
      {MediaItem? item, Episode? episode}) async {
    // Garde-fou légal sur tout le chemin de lecture (N1 Ultron) : refuse
    // les hôtes pirates connus, même si une source les fournissait.
    requireLegalSource(source.url);

    // Propage la clé OpenSubtitles enregistrée en paramètres (B4 Ultron) :
    // sans elle, la recherche de sous-titres échouait toujours.
    try {
      final serverService = await ServerConfigService.create();
      final osKey = await serverService.getOpenSubtitlesApiKey();
      if (osKey != null && osKey.isNotEmpty) {
        _subtitleService.setApiKey(osKey);
      }
    } catch (_) {
      // Clé illisible : on continue avec les .srt directs.
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      throw StateError(
        'PrinceMovie : branchez VideoPlayerService.navigatorKey sur '
        'MaterialApp (voir INTEGRATION_TADASHI.md).',
      );
    }

    // Liste complète des sources (pour le choix de qualité dans le lecteur).
    var sources = <StreamSource>[source];
    if (item != null) {
      try {
        final all = await AppServices.catalog.streams(item);
        if (all.isNotEmpty) {
          sources = all;
          if (!sources.any((s) => s.url == source.url)) {
            sources = [source, ...sources];
          }
        }
      } catch (_) {
        // On garde la source reçue.
      }
    }

    // Fichier téléchargé prioritaire (lecture hors-ligne).
    String? localPath;
    final downloads = AppServices.downloads;
    if (item != null && downloads is DownloadManager) {
      localPath = await downloads.localPathFor(
        item.id,
        quality: source.qualityLabel,
        episode: episode,
      );
    }

    final media = PlayableMedia(
      item: item ?? _placeholderItem(source),
      sources: sources,
      initialSource: source,
      seasonNumber: episode?.seasonNumber,
      episodeNumber: episode?.number,
    );
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          media: media,
          localFilePath: localPath,
          subtitleService: _subtitleService,
        ),
      ),
    );
  }

  /// Élément minimal quand la source est lue sans fiche (titre du fichier).
  /// Champs optionnels du MediaItem actuel : year, genres, rating,
  /// synopsis, posterUrl — tous nuls par défaut ici.
  MediaItem _placeholderItem(StreamSource source) {
    final name = source.url.split('/').last;
    final title = name.isEmpty
        ? 'Vidéo'
        : Uri.decodeComponent(name).replaceAll(RegExp(r'\.[^.]+$'), '');
    return MediaItem(
      id: 'url-${source.url.hashCode.abs()}',
      title: title,
      type: MediaType.movie,
    );
  }
}
