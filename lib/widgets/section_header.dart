import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Titre de section avec lien « Tous > ».
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Row(
                children: [
                  Text(
                    'Tous',
                    style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18, color: AppTheme.textMuted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
