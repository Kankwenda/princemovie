import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/stream_source.dart';
import '../models/subtitle.dart';

/// Bottom sheets de choix de source (qualité / sous-titres) pour le lecteur.
class QualitySelectorSheet {
  QualitySelectorSheet._();

  /// Affiche la feuille de choix de qualité. Retourne la source choisie,
  /// ou null si la feuille est fermée sans choix.
  ///
  /// [labelFor] donne le libellé affiché d'une source ('1080p', '720p',
  /// '480p', 'Hors-ligne' pour un fichier téléchargé...).
  static Future<StreamSource?> show(
    BuildContext context, {
    required List<StreamSource> sources,
    required StreamSource current,
    required String Function(StreamSource source) labelFor,
  }) {
    return showModalBottomSheet<StreamSource>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Qualité',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...sources.map((source) {
              final isCurrent = source.url == current.url;
              return ListTile(
                leading: Icon(
                  isCurrent && !source.url.startsWith('http')
                      ? Icons.offline_bolt
                      : Icons.high_quality,
                  color: AppTheme.gold,
                ),
                title: Text(labelFor(source)),
                subtitle: source.sizeBytes != null
                    ? Text(formatBytes(source.sizeBytes!))
                    : null,
                trailing: isCurrent
                    ? const Icon(Icons.check, color: AppTheme.gold)
                    : null,
                onTap: () => Navigator.of(context).pop(source),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Choix d'un sous-titre (fichier nul = « Aucun »).
class SubtitleSelection {
  const SubtitleSelection(this.file);

  final SubtitleFile? file;
}

class SubtitleSelectorSheet {
  SubtitleSelectorSheet._();

  /// Affiche la feuille de choix de sous-titres. Retourne la sélection
  /// (fichier choisi, ou fichier nul pour « Aucun »), ou null si la
  /// feuille est fermée sans choix.
  static Future<SubtitleSelection?> show(
    BuildContext context, {
    required List<SubtitleFile> tracks,
    required String? currentLabel,
  }) {
    String labelOf(SubtitleFile file) {
      if (file.language == 'fr') return 'Français';
      if (file.language == 'en') return 'English';
      if (file.language.isNotEmpty) return file.language;
      return file.fileName;
    }

    return showModalBottomSheet<SubtitleSelection>(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sous-titres',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.subtitles_off, color: AppTheme.gold),
              title: const Text('Aucun'),
              trailing: currentLabel == null
                  ? const Icon(Icons.check, color: AppTheme.gold)
                  : null,
              onTap: () =>
                  Navigator.of(context).pop(const SubtitleSelection(null)),
            ),
            ...tracks.map((track) {
              final label = labelOf(track);
              return ListTile(
                leading:
                    const Icon(Icons.subtitles, color: AppTheme.gold),
                title: Text(label),
                trailing: currentLabel == label
                    ? const Icon(Icons.check, color: AppTheme.gold)
                    : null,
                onTap: () => Navigator.of(context)
                    .pop(SubtitleSelection(track)),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
