// Service sous-titres : deux voies.
// 1) OpenSubtitles (https://api.opensubtitles.com/api/v1) : recherche par
//    identifiant TMDB ou par titre, puis lien de téléchargement temporaire.
//    Nécessite une clé API gratuite (compte sur opensubtitles.com) saisie
//    dans les paramètres. L'usage gratuit est limité (quelques
//    téléchargements par jour) : en cas de quota atteint, l'API renvoie 403.
// 2) URL .srt directe : récupère le texte d'un fichier .srt hébergé
//    (ex. fichier .srt d'un élément Archive.org, ou URL collée par
//    l'utilisateur). Aucune clé nécessaire.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Erreur sous-titres (clé invalide, quota, réseau, fichier invalide...).
class SubtitleException implements Exception {
  final String message;
  final int? statusCode;

  const SubtitleException(this.message, {this.statusCode});

  @override
  String toString() => 'SubtitleException(${statusCode ?? '?'}): $message';
}

class SubtitleService {
  /// URL de base de l'API OpenSubtitles v1.
  static const String baseUrl = 'https://api.opensubtitles.com/api/v1';

  final http.Client _client;
  String? _apiKey;

  SubtitleService({String? apiKey, http.Client? client})
      : _apiKey = apiKey,
        _client = client ?? http.Client();

  /// Met à jour la clé API OpenSubtitles (saisie dans les paramètres).
  void setApiKey(String apiKey) => _apiKey = apiKey.trim();

  /// Vrai si une clé API OpenSubtitles est définie.
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Libère le client HTTP. À appeler à la fermeture de l'appli.
  void dispose() => _client.close();

  // ---------------------------------------------------------------------------
  // OpenSubtitles
  // ---------------------------------------------------------------------------

  /// Recherche des sous-titres par identifiant TMDB et/ou par titre.
  /// [languages] : codes séparés par des virgules, ex. 'fr' ou 'fr,en'.
  /// Renvoie la liste des fichiers trouvés (sans lien direct : voir
  /// [downloadLink]).
  Future<List<SubtitleFile>> search({
    int? tmdbId,
    String? query,
    String languages = 'fr',
    int page = 1,
  }) async {
    if (!hasApiKey) {
      throw const SubtitleException(
          'Clé API OpenSubtitles manquante : saisis-la dans les paramètres.');
    }
    if (tmdbId == null && (query == null || query.trim().isEmpty)) {
      throw const SubtitleException(
          'Indique un identifiant TMDB ou un titre à rechercher.');
    }
    final uri = Uri.parse('$baseUrl/subtitles').replace(queryParameters: {
      'languages': languages,
      'page': '$page',
      if (tmdbId != null) 'tmdb_id': '$tmdbId',
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
    });
    try {
      final res = await _client.get(uri, headers: _headers()).timeout(
            const Duration(seconds: 20),
          );
      if (res.statusCode == 401) {
        throw const SubtitleException(
            'Clé API OpenSubtitles invalide.', statusCode: 401);
      }
      if (res.statusCode == 403) {
        throw const SubtitleException(
            'Quota OpenSubtitles gratuit atteint (réessaie plus tard).',
            statusCode: 403);
      }
      if (res.statusCode != 200) {
        throw SubtitleException(
            'OpenSubtitles a répondu ${res.statusCode}.',
            statusCode: res.statusCode);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (data['data'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SubtitleFile.fromOpenSubtitles)
          .toList();
    } on TimeoutException {
      throw const SubtitleException(
          'OpenSubtitles ne répond pas (délai dépassé).');
    }
  }

  /// Lien de téléchargement temporaire (quelques minutes) pour un fichier
  /// trouvé via [search]. [fileId] : identifiant numérique du fichier
  /// (SubtitleFile.id).
  Future<String> downloadLink(int fileId) async {
    if (!hasApiKey) {
      throw const SubtitleException(
          'Clé API OpenSubtitles manquante : saisis-la dans les paramètres.');
    }
    final uri = Uri.parse('$baseUrl/download');
    try {
      final res = await _client
          .post(
            uri,
            headers: _headers(),
            body: jsonEncode({'file_id': fileId}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401) {
        throw const SubtitleException(
            'Clé API OpenSubtitles invalide.', statusCode: 401);
      }
      if (res.statusCode != 200) {
        throw SubtitleException(
            'OpenSubtitles a répondu ${res.statusCode}.',
            statusCode: res.statusCode);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final link = data['link'] as String?;
      if (link == null || link.isEmpty) {
        throw const SubtitleException(
            'OpenSubtitles n’a pas renvoyé de lien de téléchargement.');
      }
      return link;
    } on TimeoutException {
      throw const SubtitleException(
          'OpenSubtitles ne répond pas (délai dépassé).');
    }
  }

  // ---------------------------------------------------------------------------
  // Fichier .srt direct
  // ---------------------------------------------------------------------------

  /// Récupère le texte d'un .srt depuis une URL directe
  /// (ex. https://archive.org/download/<id>/<fichier>.srt).
  /// Vérifie que le contenu ressemble bien à du SRT (présence de '-->').
  Future<String> fetchSrtText(String url) async {
    try {
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw SubtitleException(
            'Sous-titre introuvable (${res.statusCode}).',
            statusCode: res.statusCode);
      }
      // Décodage UTF-8 tolérant (les .srt sont souvent en UTF-8 ou Latin-1).
      final text = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (!text.contains('-->')) {
        throw const SubtitleException(
            'Le fichier récupéré ne ressemble pas à un .srt.');
      }
      return text;
    } on TimeoutException {
      throw const SubtitleException(
          'Le serveur du sous-titre ne répond pas (délai dépassé).');
    }
  }

  Map<String, String> _headers() => {
        'Api-Key': _apiKey!,
        'Content-Type': 'application/json',
        'User-Agent': 'PrinceMovie/1.0',
      };
}
