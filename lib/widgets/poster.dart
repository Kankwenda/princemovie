import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';

/// Palette des dégradés de repli (quand aucune affiche n'est disponible).
const _palettes = <List<int>>[
  [0xFF1F3A93, 0xFF0B0B0F],
  [0xFF6B1F1F, 0xFF0B0B0F],
  [0xFF2E4B3F, 0xFF0B0B0F],
  [0xFF4A4A2E, 0xFF0B0B0F],
  [0xFF5B2A86, 0xFF0B0B0F],
  [0xFF1F5A7A, 0xFF0B0B0F],
];

/// Affiche d'un élément : vraie image TMDB/Archive si disponible,
/// sinon dégradé + initiale du titre.
/// (Pas de badge « En français » : la langue audio n'est pas connue —
/// TMDB ne la fournit pas dans [MediaItem].)
class PosterArt extends StatelessWidget {
  const PosterArt({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.fontSize,
  });

  final MediaItem item;
  final double? width;
  final double? height;
  final double borderRadius;
  final double? fontSize;

  Widget _fallback() {
    final palette = _palettes[item.id.hashCode.abs() % _palettes.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(palette[0]), Color(palette[1])],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        item.title.isNotEmpty ? item.title[0] : '?',
        style: TextStyle(
          fontSize: fontSize ?? 48,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final posterUrl = item.posterUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (posterUrl == null)
              _fallback()
            else
              Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _fallback();
                },
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo « P » doré (utilisé dans la barre de titre).
class PrinceLogo extends StatelessWidget {
  const PrinceLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(
          fontSize: size * 0.62,
          fontWeight: FontWeight.bold,
          color: AppTheme.gold,
        ),
      ),
    );
  }
}
