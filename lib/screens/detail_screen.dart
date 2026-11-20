import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/media_actions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/media_card.dart';
import '../widgets/poster.dart';

/// Fiche détail : grande affiche, synopsis, infos, saisons/épisodes,
/// boutons Lecture / Télécharger / Favori, choix de la qualité.
///
/// Honnêteté : TMDB ne fournit que des métadonnées — Lecture et
/// Téléchargement sont désactivés quand aucune source vidéo directe
/// n'existe (films du domaine public : Internet Archive).
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.item});

  final MediaItem item;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final Future<MediaDetails> _details;
  late final Future<bool> _isFavorite;
  Future<List<Episode>>? _episodes;
  StreamQuality? _quality;
  int _season = 1;

  @override
  void initState() {
    super.initState();
    _details = AppServices.catalog.details(widget.item);
    _isFavorite = AppServices.library.isFavorite(widget.item.id);
    if (widget.item.isTv) {
      _loadEpisodes();
    }
  }

  void _loadEpisodes() {
    _episodes =
        AppServices.catalog.seasonEpisodes(widget.item, _season);
  }

  Future<void> _toggleFavorite() async {
    await AppServices.library.toggleFavorite(widget.item);
    if (!mounted) return;
    setState(() {
      _isFavorite = AppServices.library.isFavorite(widget.item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      body: FutureBuilder<MediaDetails>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Impossible de charger la fiche.'),
            );
          }
          final details = snapshot.data!;
          final playable = details.hasPlayableStreams;
          final qualities = details.streams
              .map((s) => s.quality)
              .toSet()
              .toList()
            ..sort((a, b) => b.rank.compareTo(a.rank));
          final selectedQuality =
              _quality ?? (qualities.isEmpty ? null : qualities.first);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PosterArt(item: item, borderRadius: 0, fontSize: 130),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Text(
                          details.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metaRow(details),
                      const SizedBox(height: 12),
                      Text(details.synopsis ??
                          item.synopsis ??
                          'Aucun synopsis disponible.'),
                      const SizedBox(height: 16),
                      _actionsRow(playable, selectedQuality),
                      if (!playable) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Métadonnées TMDB uniquement — pas de lecture ni '
                          'de téléchargement direct pour ce titre.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                      if (qualities.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Qualité',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: qualities.map((q) {
                            return ChoiceChip(
                              label: Text(q.label),
                              selected: selectedQuality == q,
                              onSelected: (_) =>
                                  setState(() => _quality = q),
                            );
                          }).toList(),
                        ),
                      ],
                      if (details.seasons.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Saisons',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: details.seasons.map((s) {
                            return ChoiceChip(
                              label: Text('Saison ${s.number}'),
                              selected: _season == s.number,
                              onSelected: (_) {
                                setState(() {
                                  _season = s.number;
                                  _loadEpisodes();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        _episodeList(playable, selectedQuality),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metaRow(MediaDetails details) {
    final parts = <String>[details.type == MediaType.tv ? 'Série' : 'Film'];
    if (details.year != null) parts.add('${details.year}');
    if (details.genres.isNotEmpty) parts.add(details.genres.join(', '));
    if (details.source != null) parts.add(details.source!);
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (details.rating != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 16, color: AppTheme.gold),
              const SizedBox(width: 4),
              Text(details.rating!.toStringAsFixed(1)),
            ],
          ),
        Text(parts.join(' • '),
            style: const TextStyle(color: AppTheme.textMuted)),
        if (details.runtimeMinutes != null)
          Text(
            '${details.runtimeMinutes! ~/ 60} h ${details.runtimeMinutes! % 60} min',
            style: const TextStyle(color: AppTheme.textMuted),
          ),
      ],
    );
  }

  Widget _actionsRow(bool playable, StreamQuality? quality) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: playable
                ? () => playBestAvailable(context, widget.item,
                    quality: quality)
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Lecture'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: playable
                ? () => downloadBestAvailable(context, widget.item,
                    quality: quality)
                : null,
            icon: const Icon(Icons.download),
            label: const Text('Télécharger'),
          ),
        ),
        const SizedBox(width: 10),
        FutureBuilder<bool>(
          future: _isFavorite,
          builder: (context, snapshot) {
            final fav = snapshot.data ?? false;
            return IconButton(
              icon: Icon(
                fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? AppTheme.gold : AppTheme.textPrimary,
              ),
              tooltip: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
              onPressed: _toggleFavorite,
            );
          },
        ),
      ],
    );
  }

  Widget _episodeList(bool playable, StreamQuality? quality) {
    final future = _episodes;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<List<Episode>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final episodes = snapshot.data ?? const <Episode>[];
        if (episodes.isEmpty) {
          return const Text(
            'Aucun épisode pour cette saison.',
            style: TextStyle(color: AppTheme.textMuted),
          );
        }
        return Column(
          children: episodes.map((ep) {
            return Card(
              color: AppTheme.card,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${ep.number}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gold,
                    ),
                  ),
                ),
                title: Text(ep.title ?? 'Épisode ${ep.number}'),
                subtitle: Text(
                  ep.durationMinutes == null
                      ? ''
                      : '${ep.durationMinutes} min',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Lire',
                      onPressed: playable
                          ? () => playBestAvailable(
                                context,
                                widget.item,
                                quality: quality,
                                episode: ep,
                              )
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Télécharger',
                      onPressed: playable
                          ? () => downloadBestAvailable(
                                context,
                                widget.item,
                                quality: quality,
                                episode: ep,
                              )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
