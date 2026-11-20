// Épisode d'une série (TMDB) et saison qui le contient.
// Les films Archive.org n'ont pas d'épisodes : la liste reste vide.

import 'media_item.dart';

class Episode {
  const Episode({
    this.seasonNumber,
    required this.number,
    this.title,
    this.durationMinutes,
    this.synopsis,
    this.stillUrl,
    this.airDate,
  });

  /// Numéro de la saison (peut être nul pour les épisodes de démonstration).
  final int? seasonNumber;

  /// Numéro de l'épisode dans sa saison.
  final int number;

  /// Titre de l'épisode (peut être nul).
  final String? title;

  /// Durée en minutes (peut être nulle).
  final int? durationMinutes;

  /// Résumé de l'épisode (peut être nul).
  final String? synopsis;

  /// URL de l'image de l'épisode (peut être nulle).
  final String? stillUrl;

  /// Date de diffusion 'AAAA-MM-JJ' (peut être nulle).
  final String? airDate;

  /// Épisode issu de /tv/{id}/season/{n} (TMDB).
  factory Episode.fromTmdb(
    Map<String, dynamic> json, {
    required int seasonNumber,
  }) {
    return Episode(
      seasonNumber: seasonNumber,
      number: (json['episode_number'] as num?)?.toInt() ?? 0,
      title: (json['name'] as String?)?.trim(),
      durationMinutes: (json['runtime'] as num?)?.toInt(),
      synopsis: _nonEmpty(json['overview'] as String?),
      stillUrl: MediaItem.tmdbImageUrl(json['still_path'] as String?),
      airDate: json['air_date'] as String?,
    );
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Map<String, dynamic> toJson() => {
        'seasonNumber': seasonNumber,
        'number': number,
        'title': title,
        'durationMinutes': durationMinutes,
        'synopsis': synopsis,
        'stillUrl': stillUrl,
        'airDate': airDate,
      };

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
        number: (json['number'] as num?)?.toInt() ?? 0,
        title: json['title'] as String?,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
        synopsis: json['synopsis'] as String?,
        stillUrl: json['stillUrl'] as String?,
        airDate: json['airDate'] as String?,
      );
}

/// Saison d'une série (TMDB).
class Season {
  const Season({
    required this.number,
    this.episodes = const [],
    this.name,
    this.episodeCount,
    this.posterUrl,
    this.airDate,
  });

  /// Numéro de la saison (0 = spéciaux, 1, 2, ...).
  final int number;

  /// Épisodes de la saison (chargés à la demande, vide sinon).
  final List<Episode> episodes;

  /// Nom de la saison (peut être nul, ex. 'Saison 1').
  final String? name;

  /// Nombre d'épisodes dans la saison (peut être nul).
  final int? episodeCount;

  /// URL de l'affiche de la saison (peut être nulle).
  final String? posterUrl;

  /// Date de diffusion 'AAAA-MM-JJ' (peut être nulle).
  final String? airDate;

  /// Saison issue du détail d'une série TMDB.
  factory Season.fromTmdb(Map<String, dynamic> json) => Season(
        number: (json['season_number'] as num?)?.toInt() ?? 0,
        episodes: const [],
        name: (json['name'] as String?)?.trim(),
        episodeCount: (json['episode_count'] as num?)?.toInt(),
        posterUrl: MediaItem.tmdbImageUrl(json['poster_path'] as String?),
        airDate: json['air_date'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'name': name,
        'episodeCount': episodeCount,
        'posterUrl': posterUrl,
        'airDate': airDate,
      };

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        number: (json['number'] as num?)?.toInt() ?? 0,
        episodes: (json['episodes'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Episode.fromJson)
                .toList() ??
            const [],
        name: json['name'] as String?,
        episodeCount: (json['episodeCount'] as num?)?.toInt(),
        posterUrl: json['posterUrl'] as String?,
        airDate: json['airDate'] as String?,
      );
}
