// Service TMDB (https://api.themoviedb.org/3) : MÉTADONNÉES UNIQUEMENT.
// Recherche, tendances, détails films/séries, saisons et épisodes.
// TMDB ne fournit JAMAIS de flux vidéo : aucune URL de lecture ne sort d'ici.
//
// Clé API : gratuite sur https://www.themoviedb.com/settings/api
// (compte gratuit -> clé API v3). L'utilisateur la saisit dans les paramètres
// de l'appli ; elle est stockée en local par ServerConfigService.
// Sans clé, toutes les méthodes lèvent [TmdbException].

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Erreur TMDB (clé invalide, réseau, serveur...).
class TmdbException implements Exception {
  final String message;
  final int? statusCode;

  const TmdbException(this.message, {this.statusCode});

  @override
  String toString() => 'TmdbException(${statusCode ?? '?'}): $message';
}

class TmdbService {
  /// URL de base de l'API TMDB v3.
  static const String baseUrl = 'https://api.themoviedb.org/3';

  /// Langue des réponses (français).
  static const String language = 'fr-FR';

  final http.Client _client;
  String? _apiKey;

  TmdbService({String? apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  /// Met à jour la clé API (saisie par l'utilisateur dans les paramètres).
  void setApiKey(String apiKey) => _apiKey = apiKey.trim();

  /// Vrai si une clé API est définie.
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Libère le client HTTP. À appeler à la fermeture de l'appli.
  void dispose() => _client.close();

  // ---------------------------------------------------------------------------
  // Recherche et listes
  // ---------------------------------------------------------------------------

  /// Recherche films + séries (multi). [page] commence à 1.
  Future<List<MediaItem>> search(String query, {int page = 1}) async {
    final json = await _get('/search/multi', {
      'query': query,
      'page': '$page',
      'include_adult': 'false',
    });
    final results = (json['results'] as List?) ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((e) =>
            e['media_type'] == 'movie' || e['media_type'] == 'tv')
        .map(MediaItem.fromTmdbMulti)
        .toList();
  }

  /// Tendances du moment (films + séries). [timeWindow] : 'day' ou 'week'.
  Future<List<MediaItem>> trending(
      {String timeWindow = 'week', int page = 1}) async {
    final json = await _get('/trending/all/$timeWindow', {'page': '$page'});
    final results = (json['results'] as List?) ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .where((e) =>
            e['media_type'] == 'movie' || e['media_type'] == 'tv')
        .map(MediaItem.fromTmdbMulti)
        .toList();
  }

  /// Films populaires.
  Future<List<MediaItem>> popularMovies({int page = 1}) =>
      _movieList('/movie/popular', page);

  /// Séries populaires.
  Future<List<MediaItem>> popularSeries({int page = 1}) =>
      _tvList('/tv/popular', page);

  /// Films les mieux notés.
  Future<List<MediaItem>> topRatedMovies({int page = 1}) =>
      _movieList('/movie/top_rated', page);

  /// Séries les mieux notées.
  Future<List<MediaItem>> topRatedSeries({int page = 1}) =>
      _tvList('/tv/top_rated', page);

  // ---------------------------------------------------------------------------
  // Détails, saisons, épisodes
  // ---------------------------------------------------------------------------

  /// Fiche détail d'un film (synopsis, genres, durée, affiche, fond).
  Future<MediaDetails> movieDetails(int tmdbId) async {
    final json = await _get('/movie/$tmdbId', {});
    return MediaDetails.fromTmdbMovie(json);
  }

  /// Fiche détail d'une série (synopsis, genres, saisons).
  Future<MediaDetails> tvDetails(int tmdbId) async {
    final json = await _get('/tv/$tmdbId', {});
    return MediaDetails.fromTmdbTv(json);
  }

  /// Fiche détail d'un [MediaItem] TMDB (film ou série selon son type).
  Future<MediaDetails> details(MediaItem item) {
    final id = item.tmdbId;
    if (id == null) {
      throw const TmdbException('Cet élément ne vient pas de TMDB.');
    }
    return item.type == MediaType.tv ? tvDetails(id) : movieDetails(id);
  }

  /// Épisodes d'une saison d'une série.
  Future<List<Episode>> seasonEpisodes(int tvId, int seasonNumber) async {
    final json = await _get('/tv/$tvId/season/$seasonNumber', {});
    final episodes = (json['episodes'] as List?) ?? [];
    return episodes
        .whereType<Map<String, dynamic>>()
        .map((e) => Episode.fromTmdb(e, seasonNumber: seasonNumber))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Requête HTTP
  // ---------------------------------------------------------------------------

  Future<List<MediaItem>> _movieList(String path, int page) async {
    final json = await _get(path, {'page': '$page'});
    final results = (json['results'] as List?) ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromTmdbMovie)
        .toList();
  }

  Future<List<MediaItem>> _tvList(String path, int page) async {
    final json = await _get(path, {'page': '$page'});
    final results = (json['results'] as List?) ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromTmdbTv)
        .toList();
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    if (!hasApiKey) {
      throw const TmdbException(
          'Clé API TMDB manquante : saisis-la dans les paramètres.');
    }
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {
      'api_key': _apiKey!,
      'language': language,
      ...params,
    });
    try {
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) {
        throw const TmdbException('Clé API TMDB invalide.', statusCode: 401);
      }
      if (res.statusCode != 200) {
        throw TmdbException('TMDB a répondu ${res.statusCode}.',
            statusCode: res.statusCode);
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw const TmdbException('TMDB ne répond pas (délai dépassé).');
    }
  }
}
