// Fichier de sous-titre (.srt) : trouvé via OpenSubtitles ou par URL directe.
// Le lecteur (Tadashi) charge le texte via SubtitleService.fetchSrtText().

class SubtitleFile {
  /// Identifiant du fichier chez OpenSubtitles (nul pour une URL directe).
  final String? id;

  /// Nom du fichier (ex. 'film.fr.srt').
  final String fileName;

  /// Code langue ('fr', 'en'...).
  final String language;

  /// URL directe de téléchargement (peut être nulle : utiliser alors
  /// SubtitleService.downloadLink(id) pour obtenir un lien temporaire).
  final String? downloadUrl;

  /// Format ('srt' le plus souvent).
  final String? format;

  const SubtitleFile({
    this.id,
    required this.fileName,
    required this.language,
    this.downloadUrl,
    this.format,
  });

  /// Sous-titre issu de /subtitles (OpenSubtitles API v1).
  /// Structure : data[].attributes { files: [{file_id, file_name}],
  /// language, ... }.
  factory SubtitleFile.fromOpenSubtitles(Map<String, dynamic> json) {
    final attributes =
        (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final files = (attributes['files'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final first = files.isEmpty ? const <String, dynamic>{} : files.first;
    final fileName = (first['file_name'] as String?) ??
        (attributes['subtitle_id'] as String? ?? 'subtitle.srt');
    return SubtitleFile(
      id: first['file_id']?.toString(),
      fileName: fileName,
      language: (attributes['language'] as String?) ?? '',
      format: fileName.contains('.') ? fileName.split('.').last : null,
    );
  }

  /// Sous-titre issu d'une URL directe (.srt hébergé, ex. Archive.org).
  factory SubtitleFile.fromDirectUrl(String url, {String language = ''}) {
    final name = url.split('/').last;
    return SubtitleFile(
      fileName: name.isEmpty ? 'subtitle.srt' : Uri.decodeComponent(name),
      language: language,
      downloadUrl: url,
      format: 'srt',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'language': language,
        'downloadUrl': downloadUrl,
        'format': format,
      };

  factory SubtitleFile.fromJson(Map<String, dynamic> json) => SubtitleFile(
        id: json['id'] as String?,
        fileName: json['fileName'] as String? ?? 'subtitle.srt',
        language: json['language'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String?,
        format: json['format'] as String?,
      );
}
