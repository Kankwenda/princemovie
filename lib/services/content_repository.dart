// Façade de la couche données : un seul point d'entrée pour les écrans
// (Friday) et le lecteur (Tadashi). Elle route chaque demande vers le bon
// service selon la source de l'élément (préfixe de MediaItem.id) :
// - 'tmdb:...' -> TmdbService (métadonnées uniquement, jamais de flux) ;
// - 'archive:...' -> ArchiveService (domaine public, vidéo directe).
//
// La recherche combine les deux : TMDB d'abord (catalogue riche),
// puis Archive (films libres, lisibles immédiatement). Une source en
// panne n'empêche pas l'autre de répondre.

import '../models/models.dart';
import 'archive_service.dart';
import 'tmdb_service.dart';
import 'server_config_service.dart';

class ContentRepository {
  final TmdbService tmdb;
  final ArchiveService archive;
  final ServerConfigService servers;

  ContentRepository({
    required this.tmdb,
    required this.archive,
    required this.servers,
  });

  /// Recherche un titre sur toutes les sources activées.
  /// TMDB (si la clé API est saisie) puis Internet Archive, puis les
  /// serveurs personnels activés dont le nom correspond à la requête.
  Future<List<MediaItem>> search(String query) async {
    final results = <MediaItem>[];
    if (tmdb.hasApiKey) {
      try {
        results.addAll(await tmdb.search(query));
      } catch (_) {
        // TMDB en panne ou clé invalide : on continue avec Archive.
      }
    }
    try {
      results.addAll(await archive.search(query));
    } catch (_) {
      // Archive en panne : on renvoie ce qu'on a déjà (éventuellement vide).
    }
    // Serveurs personnels activés : l'adresse saisie sert vraiment —
    // le serveur devient un élément lisible / téléchargeable.
    try {
      final q = query.trim().toLowerCase();
      for (final server in await _enabledCustomServers()) {
        if (q.isEmpty || server.name.toLowerCase().contains(q)) {
          results.add(_customItem(server));
        }
      }
    } catch (_) {
      // Stockage serveurs illisible : on renvoie ce qu'on a déjà.
    }
    return results;
  }

  /// Tendances : selon le serveur choisi dans les paramètres
  /// ('tmdb' par défaut, 'archive' possible). Sans clé TMDB, les films
  /// Archive les plus téléchargés servent de repli.
  Future<List<MediaItem>> trending() async {
    // Serveur choisi dans les paramètres : 'archive' -> films du domaine
    // public uniquement ; 'tmdb' (défaut) -> tendances TMDB.
    if (await servers.getSelectedServerId() == 'archive') {
      return archive.popular();
    }
    if (tmdb.hasApiKey) {
      try {
        return await tmdb.trending();
      } catch (_) {
        // Repli sur Archive ci-dessous.
      }
    }
    return archive.popular();
  }

  /// Fiche détail d'un élément (route selon sa source).
  Future<MediaDetails> details(MediaItem item) async {
    if (item.isTmdb) return tmdb.details(item);
    if (item.isArchive) return archive.details(item.archiveId!);
    if (item.isCustom) {
      final server = await _findCustomServer(item.customServerId);
      if (server == null) {
        throw Exception('Serveur personnel introuvable (${item.id}).');
      }
      final stream = _customStream(server);
      return MediaDetails(
        id: item.id,
        title: item.title,
        type: MediaType.movie,
        synopsis: 'Vidéo de ton serveur personnel « ${server.name} ».',
        genres: const ['Serveur personnel'],
        source: server.name,
        streams: stream == null ? const [] : [stream],
      );
    }
    throw Exception('Source inconnue pour l’élément ${item.id}.');
  }

  /// Sources vidéo directes d'un élément.
  /// Archive : fichiers MP4 (1080p/720p/480p/Source).
  /// TMDB : toujours vide (métadonnées uniquement, jamais de flux).
  /// Serveur personnel : son URL directe si c'est un fichier vidéo.
  Future<List<StreamSource>> streams(MediaItem item) async {
    if (item.isArchive) return archive.streams(item.archiveId!);
    if (item.isCustom) {
      final server = await _findCustomServer(item.customServerId);
      final stream = server == null ? null : _customStream(server);
      return stream == null ? const [] : [stream];
    }
    return const [];
  }

  /// Serveurs personnels activés (type 'custom' uniquement).
  Future<List<ServerConfig>> _enabledCustomServers() async {
    final all = await servers.enabledServers();
    return all.where((s) => s.type == ServerType.custom).toList();
  }

  /// Serveur personnel par identifiant (nul si absent).
  Future<ServerConfig?> _findCustomServer(String? id) async {
    if (id == null) return null;
    final all = await servers.loadServers();
    for (final s in all) {
      if (s.id == id && s.type == ServerType.custom) return s;
    }
    return null;
  }

  /// Élément affichable pour un serveur personnel.
  MediaItem _customItem(ServerConfig server) => MediaItem(
        id: 'custom:${server.id}',
        title: server.name,
        type: MediaType.movie,
        genres: const ['Serveur personnel'],
        synopsis: server.baseUrl,
      );

  /// Source directe d'un serveur personnel : son URL, si c'est un
  /// fichier vidéo (mp4/mkv/webm/mov/m3u8). Nul sinon (ex. racine
  /// Jellyfin/Emby : pas de fichier direct — lecture indisponible,
  /// l'interface l'explique au lieu de faire semblant).
  StreamSource? _customStream(ServerConfig server) {
    final url = server.baseUrl.trim();
    final lower = url.toLowerCase().split('?').first;
    const videoExts = ['.mp4', '.mkv', '.webm', '.mov', '.m3u8', '.avi'];
    if (!videoExts.any(lower.endsWith)) return null;
    final format = lower.endsWith('.m3u8')
        ? 'm3u8'
        : lower.split('.').last;
    return StreamSource(
      url: url,
      quality: StreamSource.qualityFromFileName(url),
      format: format,
      source: server.name,
    );
  }

  /// Épisodes d'une saison (séries TMDB uniquement).
  Future<List<Episode>> seasonEpisodes(
      MediaItem item, int seasonNumber) async {
    final id = item.tmdbId;
    if (id == null) return const [];
    return tmdb.seasonEpisodes(id, seasonNumber);
  }
}
