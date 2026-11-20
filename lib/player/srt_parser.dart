import 'package:chewie/chewie.dart';

/// Parseur de sous-titres .srt vers les [Subtitle] de chewie.
///
/// Format attendu :
/// ```text
/// 1
/// 00:00:01,000 --> 00:00:04,000
/// Première ligne
/// Deuxième ligne
///
/// 2
/// 00:00:05,500 --> 00:00:08,000
/// Texte suivant
/// ```
/// Les blocs mal formés sont ignorés (jamais de plantage).
class SrtParser {
  SrtParser._();

  /// Parse le contenu texte d'un fichier .srt.
  static List<Subtitle> parse(String srtContent) {
    final normalized =
        srtContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final subtitles = <Subtitle>[];
    var autoIndex = 0;
    for (final block in blocks) {
      final lines = block
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;
      // Première ligne : index numérique (optionnel).
      var cursor = 0;
      var index = autoIndex;
      if (int.tryParse(lines[0]) != null) {
        index = int.parse(lines[0]);
        cursor = 1;
      }
      if (lines.length - cursor < 2) continue;
      final timeLine = lines[cursor];
      final timeParts = timeLine.split('-->');
      if (timeParts.length != 2) continue;
      final start = _parseTimestamp(timeParts[0]);
      final end = _parseTimestamp(timeParts[1]);
      if (start == null || end == null || end <= start) continue;
      final texts = lines
          .sublist(cursor + 1)
          .map(_stripTags)
          .where((t) => t.isNotEmpty)
          .toList();
      if (texts.isEmpty) continue;
      subtitles.add(
        Subtitle(index: index, start: start, end: end, texts: texts),
      );
      autoIndex++;
    }
    return subtitles;
  }

  /// Parse "00:01:23,456" (ou "00:01:23.456"). Null si invalide.
  static Duration? _parseTimestamp(String raw) {
    final cleaned = raw.trim().replaceAll('.', ',');
    final hms = cleaned.split(':');
    if (hms.length != 3) return null;
    final hours = int.tryParse(hms[0]);
    final minutes = int.tryParse(hms[1]);
    final secParts = hms[2].split(',');
    final seconds = int.tryParse(secParts[0]);
    final millis = secParts.length > 1 ? int.tryParse(secParts[1]) ?? 0 : 0;
    if (hours == null || minutes == null || seconds == null) return null;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }

  /// Retire les balises HTML (<i>, <b>, <font ...>, ...) du texte.
  static String _stripTags(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
