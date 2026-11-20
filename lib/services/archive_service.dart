// Service Internet Archive (https://archive.org) : films du DOMAINE PUBLIC
// et contenus Creative Commons UNIQUEMENT (collection 'feature_films').
// Recherche via advancedsearch.php, détails via /metadata/<identifier>,
// fichiers vidéo directs https://archive.org/download/<id>/<fichier>.
//
// Vérifié le 20 nov. 2026 : advancedsearch.php répond, la collection
// feature_films contient des milliers de films ; /metadata/<id> renvoie
// 'metadata' (titre, année, description, créateur) et 'files'
// (nom, format, taille). Les descriptions peuvent contenir du HTML
// (texte Wikipédia) : elles sont nettoyées ici avant usage.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Erreur Internet Archive (réseau, élément introuvable, serveur...).
class ArchiveException implements Exception {
  final String message;
  final int? statusCode;

  const ArchiveException(this.message, {this.statusCode});

  @override
  String toString() => 'ArchiveException(${statusCode ?? '?'}): $message';
}

class ArchiveService {
  /// URL de base d'Internet Archive.
  static const String baseUrl = 'https://archive.org';

  /// Collection utilisée : longs-métrages du domaine public.
  static const String collection = 'feature_films';

  final http.Client _client;

  ArchiveService({http.Client? client}) : _client = client ?? http.Client();

  /// Libère le client HTTP. À appeler à la fermeture de l'appli.
  void dispose() => _client.close();

  // ---------------------------------------------------------------------------
  // URLs publiques (stables, utilisables par le lecteur et les téléchargements)
  // ---------------------------------------------------------------------------

  /// URL de l'affiche d'un élément.
  static String posterUrl(String identifier) =>
      '$baseUrl/services/img/$identifier';

  /// URL directe d'un fichier de l'élément.
  static String downloadUrl(String identifier, String fileName) =>
      '$baseUrl/download/$identifier/${Uri.encodeComponent(fileName)}';

  // ---------------------------------------------------------------------------
  // Recherche et listes
  // ---------------------------------------------------------------------------

  /// Recherche un film du domaine public par titre.
  /// D'abord une recherche sur le titre, puis (si vide) une recherche
  /// élargie sur tous les champs. [page] commence à 1.
  Future<List<MediaItem>> search(String query,
      {int page = 1, int rows = 20}) async {
    final clean = _escapeQuery(query);
    if (clean.isEmpty) return const [];
    var items = await _advancedSearch(
      'collection:$collection AND title:($clean)',
      page: page,
      rows: rows,
    );
    if (items.isEmpty) {
      items = await _advancedSearch(
        'collection:$collection AND ($clean)',
        page: page,
        rows: rows,
      );
    }
    return items;
  }

  /// Films les plus téléchargés de la collection (pour l'écran d'accueil).
  Future<List<MediaItem>> popular({int page = 1, int rows = 20}) async {
    return _advancedSearch(
      'collection:$collection',
      page: page,
      rows: rows,
      sort: 'downloads desc',
    );
  }

  // ---------------------------------------------------------------------------
  // Détails et sources vidéo
  // ---------------------------------------------------------------------------

  /// Fiche détail d'un film : métadonnées + sources vidéo directes.
  Future<MediaDetails> details(String identifier) async {
    final uri = Uri.parse('$baseUrl/metadata/$identifier');
    final Map<String, dynamic> data;
    try {
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 404) {
        throw ArchiveException("Film introuvable sur Archive.org : '$identifier'.",
            statusCode: 404);
      }
      if (res.statusCode != 200) {
        throw ArchiveException('Archive.org a répondu ${res.statusCode}.',
            statusCode: res.statusCode);
      }
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } on TimeoutException {
      throw const ArchiveException('Archive.org ne répond pas (délai dépassé).');
    }
    final metadata =
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
    final files = (data['files'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    final synopsis = _stripHtml(_firstString(metadata['description']));
    final subtitleUrl = _bestSubtitleUrl(identifier, files);
    final streams = _streamsFromFiles(identifier, files)
        .map((s) => s.copyWith(subtitleUrl: subtitleUrl ?? s.subtitleUrl))
        .toList();
    return MediaDetails.fromArchive(
      identifier: identifier,
      metadata: metadata,
      streams: streams,
      synopsis: synopsis,
    );
  }

  /// Sources vidéo directes d'un film (1080p / 720p / 480p / Source).
  Future<List<StreamSource>> streams(String identifier) async {
    return (await details(identifier)).streams;
  }

  // ---------------------------------------------------------------------------
  // Requête de recherche
  // ---------------------------------------------------------------------------

  Future<List<MediaItem>> _advancedSearch(
    String query, {
    required int page,
    required int rows,
    String? sort,
  }) async {
    final uri = Uri.parse('$baseUrl/advancedsearch.php').replace(
      queryParametersAll: {
        'q': [query],
        'fl[]': ['identifier', 'title', 'year', 'description', 'mediatype'],
        'rows': ['$rows'],
        'page': ['$page'],
        'output': ['json'],
        if (sort != null) 'sort': [sort],
      },
    );
    try {
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw ArchiveException('Archive.org a répondu ${res.statusCode}.',
            statusCode: res.statusCode);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final response =
          (data['response'] as Map?)?.cast<String, dynamic>() ?? {};
      final docs = (response['docs'] as List?) ?? [];
      return docs
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromArchive)
          .toList();
    } on TimeoutException {
      throw const ArchiveException('Archive.org ne répond pas (délai dépassé).');
    }
  }

  // ---------------------------------------------------------------------------
  // Fichiers -> sources vidéo et sous-titres
  // ---------------------------------------------------------------------------

  /// Extensions vidéo acceptées (le MP4 est préféré au moment du tri).
  static const _videoExtensions = ['.mp4', '.mkv', '.webm', '.mpg', '.ogv'];

  List<StreamSource> _streamsFromFiles(
      String identifier, List<Map<String, dynamic>> files) {
    final candidates = files.where((file) {
      final name = (file['name'] as String? ?? '').toLowerCase();
      return _videoExtensions.any(name.endsWith);
    }).toList();
    // MP4 d'abord : en cas de doublon de qualité, c'est lui qui est gardé.
    candidates.sort((a, b) {
      final aMp4 =
          (a['name'] as String? ?? '').toLowerCase().endsWith('.mp4') ? 0 : 1;
      final bMp4 =
          (b['name'] as String? ?? '').toLowerCase().endsWith('.mp4') ? 0 : 1;
      return aMp4.compareTo(bMp4);
    });
    final sources = candidates
        .map((file) => StreamSource.fromArchiveFile(
              identifier: identifier,
              file: file,
            ))
        .toList();
    return StreamSource.dedupeByQuality(sources);
  }

  /// Meilleur sous-titre .srt de l'élément : français d'abord, puis anglais,
  /// puis le premier disponible. Renvoie son URL directe (ou null).
  String? _bestSubtitleUrl(
      String identifier, List<Map<String, dynamic>> files) {
    final srts = files
        .map((file) => file['name'] as String? ?? '')
        .where((name) => name.toLowerCase().endsWith('.srt'))
        .toList();
    if (srts.isEmpty) return null;
    final pick = srts.firstWhere(
      (name) => name.toLowerCase().contains('.fr.'),
      orElse: () => srts.firstWhere(
        (name) => name.toLowerCase().contains('.en.'),
        orElse: () => srts.first,
      ),
    );
    return downloadUrl(identifier, pick);
  }

  // ---------------------------------------------------------------------------
  // Petits nettoyages
  // ---------------------------------------------------------------------------

  /// Premier texte d'un champ qui peut être une chaîne ou une liste.
  static String? _firstString(dynamic value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return '${value.first}';
    return null;
  }

  /// Retire les balises HTML d'une description (souvent du texte Wikipédia),
  /// décode les entités courantes et limite la taille.
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
    if (text.isEmpty) return null;
    if (text.length > 2000) text = '${text.substring(0, 2000).trim()}…';
    return text;
  }

  /// Retire les caractères spéciaux de la syntaxe de recherche Lucene.
  static String _escapeQuery(String query) {
    return query.replaceAll(RegExp(r'[():\"\\+\-]'), ' ').trim();
  }
}
