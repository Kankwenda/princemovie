// Fiche détail d'un film ou d'une série.
// Pour TMDB : métadonnées uniquement, jamais de flux vidéo.
// Pour Internet Archive : métadonnées + sources vidéo directes (domaine public).

import 'episode.dart';
import 'media_item.dart';
import 'stream_source.dart';

class MediaDetails {
  const MediaDetails({
    required this.id,
    required this.title,
    required this.type,
    this.synopsis,
    this.genres = const [],
    this.posterUrl,
    this.backdropUrl,
    this.year,
    this.rating,
    this.runtimeMinutes,
    this.seasons = const [],
    this.source,
    this.streams = const [],
  });

  /// Même identifiant préfixé que [MediaItem] ('tmdb:123' / 'archive:<id>').
  final String id;

  /// Titre affiché.
  final String title;

  /// Film ou série.
  final MediaType type;

  /// Synopsis long (peut être nul).
  final String? synopsis;

  /// Genres (ex. ['Action', 'Drame'] ; ['Domaine public'] pour Archive).
  final List<String> genres;

  /// URL de l'affiche (peut être nulle).
  final String? posterUrl;

  /// URL du fond d'écran (TMDB uniquement, peut être nulle).
  final String? backdropUrl;

  /// Année de sortie (peut être nulle).
  final int? year;

  /// Note moyenne sur 10 (TMDB uniquement, nulle pour Archive).
  final double? rating;

  /// Durée en minutes (film : runtime ; série : durée d'un épisode).
  final int? runtimeMinutes;

  /// Saisons de la série (vide pour un film).
  final List<Season> seasons;

  /// Origine des données : 'TMDB' ou 'Internet Archive'.
  final String? source;

  /// Sources vidéo directes (Archive uniquement ; vide pour TMDB).
  final List<StreamSource> streams;

  /// Vrai si une lecture directe est possible (sources Archive).
  bool get hasPlayableStreams => streams.isNotEmpty;

  /// Élément correspondant à cette fiche (pour le lecteur : PlayableMedia
  /// attend un [MediaItem]). Reconstruit depuis les champs plats.
  MediaItem get item => MediaItem(
        id: id,
        title: title,
        type: type,
        year: year,
        genres: genres,
        rating: rating,
        synopsis: synopsis,
        posterUrl: posterUrl,
      );

  // ---------------------------------------------------------------------------
  // Fabriques TMDB
  // ---------------------------------------------------------------------------

  /// Fiche détail d'un film TMDB (métadonnées uniquement, pas de flux).
  factory MediaDetails.fromTmdbMovie(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    return MediaDetails(
      id: 'tmdb:$id',
      title: _nonEmpty(json['title'] as String?) ?? 'Titre inconnu',
      type: MediaType.movie,
      synopsis: _nonEmpty(json['overview'] as String?),
      genres: _genresFromJson(json),
      posterUrl: MediaItem.tmdbImageUrl(json['poster_path'] as String?),
      backdropUrl:
          MediaItem.tmdbImageUrl(json['backdrop_path'] as String?, size: 'w780'),
      year: MediaItem.yearFromDate(json['release_date'] as String?),
      rating: (json['vote_average'] as num?)?.toDouble(),
      runtimeMinutes: (json['runtime'] as num?)?.toInt(),
      source: 'TMDB',
    );
  }

  /// Fiche détail d'une série TMDB (métadonnées + saisons, pas de flux).
  factory MediaDetails.fromTmdbTv(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    final seasons = (json['seasons'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Season.fromTmdb)
            .where((s) => s.number > 0) // on ignore la saison 0 (spéciaux)
            .toList() ??
        const <Season>[];
    final runtimes = (json['episode_run_time'] as List?)
            ?.whereType<num>()
            .map((n) => n.toInt())
            .toList() ??
        const <int>[];
    return MediaDetails(
      id: 'tmdb:$id',
      title: _nonEmpty(json['name'] as String?) ?? 'Titre inconnu',
      type: MediaType.tv,
      synopsis: _nonEmpty(json['overview'] as String?),
      genres: _genresFromJson(json),
      posterUrl: MediaItem.tmdbImageUrl(json['poster_path'] as String?),
      backdropUrl:
          MediaItem.tmdbImageUrl(json['backdrop_path'] as String?, size: 'w780'),
      year: MediaItem.yearFromDate(json['first_air_date'] as String?),
      rating: (json['vote_average'] as num?)?.toDouble(),
      runtimeMinutes: runtimes.isEmpty ? null : runtimes.first,
      seasons: seasons,
      source: 'TMDB',
    );
  }

  // ---------------------------------------------------------------------------
  // Fabrique Internet Archive
  // ---------------------------------------------------------------------------

  /// Fiche détail d'un film Archive.org.
  /// [metadata] : bloc 'metadata' de /metadata/<identifier> ;
  /// [synopsis] : description déjà nettoyée (HTML retiré) par le service ;
  /// [streams] : sources vidéo directes extraites des fichiers.
  factory MediaDetails.fromArchive({
    required String identifier,
    required Map<String, dynamic> metadata,
    required List<StreamSource> streams,
    String? synopsis,
  }) {
    final title = (metadata['title'] as String?)?.trim() ?? identifier;
    final rawYear = metadata['year'];
    final yearMatch =
        RegExp(r'\d{4}').firstMatch(rawYear == null ? '' : '$rawYear');
    return MediaDetails(
      id: 'archive:$identifier',
      title: title,
      type: MediaType.movie,
      synopsis: synopsis,
      genres: const ['Domaine public'],
      posterUrl: MediaItem.archivePosterUrl(identifier),
      year: yearMatch == null ? null : int.tryParse(yearMatch.group(0)!),
      source: 'Internet Archive',
      streams: streams,
    );
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  static List<String> _genresFromJson(Map<String, dynamic> json) {
    final genres = json['genres'];
    if (genres is List) {
      return genres
          .whereType<Map<String, dynamic>>()
          .map((g) => g['name'] as String?)
          .whereType<String>()
          .toList();
    }
    return const [];
  }
}
