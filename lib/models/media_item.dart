// Modèle de base : un film ou une série, tel qu'affiché dans les listes
// (accueil, recherche, favoris, historique).
//
// L'identifiant est préfixé par sa source :
// - 'tmdb:123' pour TMDB (métadonnées uniquement, jamais de flux vidéo) ;
// - 'archive:<identifier>' pour Internet Archive (domaine public) ;
// - 'custom:<serverId>' pour un serveur personnel (URL directe de vidéo).
// Ce préfixe permet aux services de router chaque élément vers le bon
// service sans ambiguïté.

/// Film ou série.
enum MediaType { movie, tv }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.year,
    this.genres = const [],
    this.rating,
    this.synopsis,
    this.posterUrl,
  });

  /// Identifiant unique préfixé : 'tmdb:123' ou 'archive:<identifier>'.
  final String id;

  /// Titre affiché.
  final String title;

  /// Film ou série.
  final MediaType type;

  /// Année de sortie (nulle si inconnue).
  final int? year;

  /// Genres (ex. ['Action', 'Drame'] ; ['Domaine public'] pour Archive).
  final List<String> genres;

  /// Note moyenne sur 10 (TMDB uniquement, nulle pour Archive).
  final double? rating;

  /// Court résumé (peut être nul).
  final String? synopsis;

  /// URL complète de l'affiche (peut être nulle si inconnue).
  final String? posterUrl;

  /// Vrai si c'est une série.
  bool get isTv => type == MediaType.tv;

  /// Alias de [isTv] (utilisé par RepositoryCatalog / l'écran d'accueil).
  bool get isSeries => isTv;

  /// Vrai si c'est un film.
  bool get isMovie => type == MediaType.movie;

  /// Vrai si l'élément vient de TMDB.
  bool get isTmdb => id.startsWith('tmdb:');

  /// Vrai si l'élément vient d'Internet Archive.
  bool get isArchive => id.startsWith('archive:');

  /// Vrai si l'élément est un serveur personnel ajouté par l'utilisateur.
  bool get isCustom => id.startsWith('custom:');

  /// Identifiant du serveur personnel (nul si ce n'est pas un 'custom:').
  String? get customServerId => isCustom ? id.substring(7) : null;

  /// Identifiant numérique TMDB (nul si l'élément ne vient pas de TMDB).
  int? get tmdbId => isTmdb ? int.tryParse(id.substring(5)) : null;

  /// Identifiant Archive.org (nul si l'élément ne vient pas d'Archive).
  String? get archiveId => isArchive ? id.substring(8) : null;

  MediaItem copyWith({
    String? title,
    int? year,
    List<String>? genres,
    double? rating,
    String? synopsis,
    String? posterUrl,
  }) {
    return MediaItem(
      id: id,
      title: title ?? this.title,
      type: type,
      year: year ?? this.year,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      synopsis: synopsis ?? this.synopsis,
      posterUrl: posterUrl ?? this.posterUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Fabriques TMDB
  // ---------------------------------------------------------------------------

  /// URL d'image TMDB. [size] : 'w500' (affiches), 'w780' (fonds d'écran).
  static String? tmdbImageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$path';
  }

  /// Année extraite d'une date 'AAAA-MM-JJ' (nulle si absente).
  static int? yearFromDate(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }

  /// Genres TMDB (noms français) pour les listes (genre_ids).
  static const Map<int, String> tmdbGenreNames = {
    28: 'Action',
    12: 'Aventure',
    16: 'Animation',
    35: 'Comédie',
    80: 'Crime',
    99: 'Documentaire',
    18: 'Drame',
    10751: 'Familial',
    14: 'Fantastique',
    36: 'Histoire',
    27: 'Horreur',
    10402: 'Musique',
    9648: 'Mystère',
    10749: 'Romance',
    878: 'Science-fiction',
    10770: 'Téléfilm',
    53: 'Thriller',
    10752: 'Guerre',
    37: 'Western',
    10759: 'Action & Aventure',
    10762: 'Enfants',
    10763: 'Actualités',
    10764: 'Télé-réalité',
    10765: 'SF & Fantastique',
    10766: 'Soap',
    10767: 'Talk-show',
    10768: 'Guerre & Politique',
  };

  static List<String> _genresFromJson(Map<String, dynamic> json) {
    final genres = json['genres'];
    if (genres is List) {
      return genres
          .whereType<Map<String, dynamic>>()
          .map((g) => g['name'] as String?)
          .whereType<String>()
          .toList();
    }
    final ids = json['genre_ids'];
    if (ids is List) {
      return ids
          .whereType<num>()
          .map((id) => tmdbGenreNames[id.toInt()])
          .whereType<String>()
          .toList();
    }
    return const [];
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  factory MediaItem.fromTmdbMovie(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return MediaItem(
      id: 'tmdb:$id',
      title: _nonEmpty(json['title'] as String?) ?? 'Titre inconnu',
      type: MediaType.movie,
      year: yearFromDate(json['release_date'] as String?),
      genres: _genresFromJson(json),
      rating: (json['vote_average'] as num?)?.toDouble(),
      synopsis: _nonEmpty(json['overview'] as String?),
      posterUrl: tmdbImageUrl(json['poster_path'] as String?),
    );
  }

  factory MediaItem.fromTmdbTv(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return MediaItem(
      id: 'tmdb:$id',
      title: _nonEmpty(json['name'] as String?) ?? 'Titre inconnu',
      type: MediaType.tv,
      year: yearFromDate(json['first_air_date'] as String?),
      genres: _genresFromJson(json),
      rating: (json['vote_average'] as num?)?.toDouble(),
      synopsis: _nonEmpty(json['overview'] as String?),
      posterUrl: tmdbImageUrl(json['poster_path'] as String?),
    );
  }

  /// Résultat de /search/multi : le champ 'media_type' décide film / série.
  factory MediaItem.fromTmdbMulti(Map<String, dynamic> json) {
    if (json['media_type'] == 'tv') return MediaItem.fromTmdbTv(json);
    return MediaItem.fromTmdbMovie(json);
  }

  // ---------------------------------------------------------------------------
  // Fabrique Internet Archive
  // ---------------------------------------------------------------------------

  /// URL de l'affiche d'un élément Archive.org.
  static String archivePosterUrl(String identifier) =>
      'https://archive.org/services/img/$identifier';

  /// Document issu de advancedsearch.php (champs : identifier, title, year,
  /// description, mediatype). Les films Archive sont toujours des films.
  factory MediaItem.fromArchive(Map<String, dynamic> json) {
    final identifier = (json['identifier'] as String?)?.trim() ?? '';
    final rawYear = json['year'];
    final yearMatch =
        RegExp(r'\d{4}').firstMatch(rawYear == null ? '' : '$rawYear');
    return MediaItem(
      id: 'archive:$identifier',
      title: _nonEmpty(json['title'] as String?) ?? identifier,
      type: MediaType.movie,
      year: yearMatch == null ? null : int.tryParse(yearMatch.group(0)!),
      genres: const ['Domaine public'],
      rating: null,
      synopsis: _stripHtml(json['description'] as String?),
      posterUrl: identifier.isEmpty ? null : archivePosterUrl(identifier),
    );
  }

  /// Retire les balises HTML d'une description (souvent du texte Wikipédia).
  static String? _stripHtml(String? html) {
    if (html == null || html.trim().isEmpty) return null;
    var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? null : text;
  }

  // ---------------------------------------------------------------------------
  // Sérialisation (favoris, historique)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'year': year,
        'genres': genres,
        'rating': rating,
        'synopsis': synopsis,
        'posterUrl': posterUrl,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] as String?;
    final type = typeValue == 'tv' || typeValue == 'series'
        ? MediaType.tv
        : MediaType.movie;
    return MediaItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Titre inconnu',
      type: type,
      year: (json['year'] as num?)?.toInt(),
      genres:
          (json['genres'] as List?)?.whereType<String>().toList() ?? const [],
      rating: (json['rating'] as num?)?.toDouble(),
      synopsis: json['synopsis'] as String? ?? json['overview'] as String?,
      posterUrl: json['posterUrl'] as String?,
    );
  }
}
