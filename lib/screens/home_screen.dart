import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/media_actions.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/media_card.dart';
import '../widgets/poster.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';
import 'settings_screen.dart';

/// Accueil — barre de recherche en haut, bannière mise en avant,
/// rangées « Séries Tendance » et « Films Tendance ».
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSearchTap});

  /// Bascule vers l'onglet Recherche.
  final VoidCallback onSearchTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<MediaItem>> _trending;

  @override
  void initState() {
    super.initState();
    _trending = AppServices.catalog.trending();
  }

  void _openDetail(MediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            PrinceLogo(size: 32),
            SizedBox(width: 10),
            Text('PrinceMovie'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: FutureBuilder<List<MediaItem>>(
        future: _trending,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text('Impossible de charger le catalogue.'),
            );
          }
          final items = snapshot.data!;
          final series = items.where((i) => i.isTv).toList();
          final movies = items.where((i) => i.isMovie).toList();
          final hero = items.isNotEmpty ? items.first : null;
          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _searchBar(),
                  if (hero != null) _heroBanner(hero),
                  _continueWatching(),
                  if (series.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Séries Tendance',
                      onSeeAll: widget.onSearchTap,
                    ),
                    MediaRow(items: series, onTapItem: _openDetail),
                  ],
                  if (movies.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Films Tendance',
                      onSeeAll: widget.onSearchTap,
                    ),
                    MediaRow(items: movies, onTapItem: _openDetail),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: GestureDetector(
        onTap: widget.onSearchTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppTheme.textMuted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rechercher un film/une série/un audio',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroBanner(MediaItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _openDetail(item),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PosterArt(item: item, borderRadius: 16, fontSize: 110),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 72,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.tv,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          mediaMetaLine(item),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.gold,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.download, color: Colors.black),
                    tooltip: 'Télécharger',
                    onPressed: () => downloadBestAvailable(context, item),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _continueWatching() {
    return FutureBuilder<List<HistoryEntry>>(
      future: AppServices.library.continueWatching(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <HistoryEntry>[];
        if (entries.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Continuer à regarder'),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return GestureDetector(
                    onTap: () => _openDetail(entry.item),
                    child: SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PosterArt(
                            item: entry.item,
                            width: 160,
                            height: 140,
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: entry.progress,
                            backgroundColor: AppTheme.surface,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.positionLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
