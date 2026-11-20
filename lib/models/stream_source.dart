// Source vidéo directe : une URL de fichier lisible par le lecteur
// (et téléchargeable avec pause/reprise par la couche téléchargements).
// Provient uniquement de sources légales (Internet Archive, serveur personnel).
// TMDB ne fournit JAMAIS de StreamSource : ce ne sont que des métadonnées.

/// Qualité vidéo disponible.
enum StreamQuality {
  /// 1080p (Full HD).
  q1080,

  /// 720p (HD).
  q720,

  /// 480p (SD).
  q480,

  /// Qualité d'origine du fichier (résolution non indiquée dans le nom).
  source,
}

extension StreamQualityExtension on StreamQuality {
  /// Libellé affiché dans le sélecteur de qualité.
  String get label {
    switch (this) {
      case StreamQuality.q1080:
        return '1080p';
      case StreamQuality.q720:
        return '720p';
      case StreamQuality.q480:
        return '480p';
      case StreamQuality.source:
        return 'Source';
    }
  }

  /// Rang pour trier de la meilleure à la moins bonne qualité.
  int get rank {
    switch (this) {
      case StreamQuality.q1080:
        return 4;
      case StreamQuality.q720:
        return 3;
      case StreamQuality.q480:
        return 2;
      case StreamQuality.source:
        return 1;
    }
  }

  /// Valeur stockée en local.
  String get storageValue => name;

  static StreamQuality fromStorage(String? value) {
    switch (value) {
      case 'q1080':
        return StreamQuality.q1080;
      case 'q720':
        return StreamQuality.q720;
      case 'q480':
        return StreamQuality.q480;
      case 'source':
      default:
        return StreamQuality.source;
    }
  }
}

class StreamSource {
  /// URL directe du fichier vidéo (ex. https://archive.org/download/...mp4).
  final String url;

  /// Qualité de cette source.
  final StreamQuality quality;

  /// Langue audio (ex. 'fr', 'en'), nulle si inconnue.
  final String? language;

  /// URL directe d'un sous-titre .srt (peut être nulle).
  final String? subtitleUrl;

  /// Format du fichier ('mp4', 'mkv', 'webm'...).
  final String format;

  /// Origine affichée (ex. 'Internet Archive').
  final String source;

  /// Taille du fichier en octets (peut être nulle si inconnue).
  final int? sizeBytes;

  const StreamSource({
    required this.url,
    required this.quality,
    this.language,
    this.subtitleUrl,
    this.format = 'mp4',
    required this.source,
    this.sizeBytes,
  });

  /// Libellé de qualité ('1080p', '720p', '480p', 'Source').
  String get qualityLabel => quality.label;

  StreamSource copyWith({String? subtitleUrl, String? language}) {
    return StreamSource(
      url: url,
      quality: quality,
      language: language ?? this.language,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      format: format,
      source: source,
      sizeBytes: sizeBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Détection de la qualité depuis le nom du fichier Archive.org
  // ---------------------------------------------------------------------------

  /// Déduit la qualité du nom de fichier :
  /// '1080' -> 1080p, '720' -> 720p, '512kb' ou '480' -> 480p,
  /// sinon qualité d'origine ('Source').
  static StreamQuality qualityFromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.contains('1080')) return StreamQuality.q1080;
    if (lower.contains('720')) return StreamQuality.q720;
    if (lower.contains('512kb') || lower.contains('480')) {
      return StreamQuality.q480;
    }
    return StreamQuality.source;
  }

  /// Source construite depuis un fichier de /metadata/<identifier>.
  /// [identifier] : identifiant Archive.org ; [file] : entrée de 'files'
  /// (champs 'name', 'format', 'size').
  factory StreamSource.fromArchiveFile({
    required String identifier,
    required Map<String, dynamic> file,
    String? subtitleUrl,
  }) {
    final name = (file['name'] as String?) ?? '';
    final format = (file['format'] as String?)?.toLowerCase() ?? 'mp4';
    return StreamSource(
      url:
          'https://archive.org/download/$identifier/${Uri.encodeComponent(name)}',
      quality: qualityFromFileName(name),
      subtitleUrl: subtitleUrl,
      format: format.contains('mpeg4') ? 'mp4' : format,
      source: 'Internet Archive',
      sizeBytes: int.tryParse('${file['size'] ?? ''}'),
    );
  }

  /// Garde une seule source par qualité (la première, donc le MP4 si les
  /// fichiers ont été triés MP4 d'abord) et trie de la meilleure qualité
  /// à la moins bonne.
  static List<StreamSource> dedupeByQuality(List<StreamSource> sources) {
    final byQuality = <StreamQuality, StreamSource>{};
    for (final s in sources) {
      byQuality.putIfAbsent(s.quality, () => s);
    }
    final list = byQuality.values.toList();
    list.sort((a, b) => b.quality.rank.compareTo(a.quality.rank));
    return list;
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'quality': quality.storageValue,
        'language': language,
        'subtitleUrl': subtitleUrl,
        'format': format,
        'source': source,
        'sizeBytes': sizeBytes,
      };

  factory StreamSource.fromJson(Map<String, dynamic> json) => StreamSource(
        url: json['url'] as String? ?? '',
        quality: StreamQualityExtension.fromStorage(
            json['quality'] as String?),
        language: json['language'] as String?,
        subtitleUrl: json['subtitleUrl'] as String?,
        format: json['format'] as String? ?? 'mp4',
        source: json['source'] as String? ?? '',
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
      );
}
