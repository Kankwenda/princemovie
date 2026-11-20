import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../widgets/media_card.dart';
import '../widgets/poster.dart';
import '../widgets/section_header.dart';
import 'detail_screen.dart';

/// Favoris + historique « Continuer à regarder » (stockage local).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<MediaItem>> _favorites;
  late Future<List<HistoryEntry>> _history;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _favorites = AppServices.library.favorites();
    _history = AppServices.library.continueWatching();
  }

  void _openDetail(MediaItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
    );
    // Rafraîchir au retour (un favori a pu être retiré).
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoris')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _historySection(),
            const SectionHeader(title: 'Mes favoris'),
            _favoritesSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _historySection() {
    return FutureBuilder<List<HistoryEntry>>(
      future: _history,
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
                  return SizedBox(
                    width: 160,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _openDetail(entry.item),
                          child: Stack(
                            children: [
                              PosterArt(
                                item: entry.item,
                                width: 160,
                                height: 140,
                              ),
                              Positioned.fill(
                                child: Icon(
                                  Icons.play_circle_filled,
                                  size: 44,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: () async {
                                    await AppServices.library
                                        .removeFromHistory(entry.item.id);
                                    if (mounted) setState(_load);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                          '${entry.item.title} · ${entry.positionLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
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

  Widget _favoritesSection() {
    return FutureBuilder<List<MediaItem>>(
      future: _favorites,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <MediaItem>[];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.favorite_border,
                      size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Aucun favori pour le moment.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.58,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return MediaCard(
              item: item,
              width: double.infinity,
              posterHeight: 150,
              onTap: () => _openDetail(item),
            );
          },
        );
      },
    );
  }
}
