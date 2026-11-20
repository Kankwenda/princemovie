import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import 'poster.dart';

/// Ligne de métadonnées sous le titre : « Série • 2021 • ★ 7.9 ».
String mediaMetaLine(MediaItem item) {
  final parts = <String>[item.isTv ? 'Série' : 'Film'];
  if (item.year != null) parts.add('${item.year}');
  if (item.rating != null) parts.add('★ ${item.rating!.toStringAsFixed(1)}');
  return parts.join(' • ');
}

/// Carte d'affiche : visuel + titre + métadonnées (comme sur la capture).
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    this.onTap,
    this.width = 120,
    this.posterHeight = 170,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final double width;
  final double posterHeight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PosterArt(
              item: item,
              width: width,
              height: posterHeight,
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              mediaMetaLine(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rangée horizontale défilante de cartes.
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.items,
    required this.onTapItem,
  });

  final List<MediaItem> items;
  final void Function(MediaItem item) onTapItem;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return MediaCard(item: item, onTap: () => onTapItem(item));
        },
      ),
    );
  }
}
