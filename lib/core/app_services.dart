/// Point d'entrée des écrans vers la couche données (Edith) et les
/// services à venir (Tadashi).
///
/// - Catalogue : [CatalogPort] — [RepositoryCatalog] adapte le vrai
///   [ContentRepository] d'Edith ; [MockCatalog] fournit des données de
///   démonstration tant que les services réels ne sont pas branchés.
/// - Favoris / historique : [LibraryService] (Edith : LocalLibraryService).
/// - Lecteur : [PlayerService] (à Tadashi).
/// - Téléchargements : [DownloadService] (à Tadashi).
///
/// Branchement des vrais services (dans `main()`, via
/// `AppServices.initRealServices()`) ; pour le lecteur et les
/// téléchargements : `AppServices.configure(player: …, downloads: …)`.

import '../models/download_item.dart';
import '../models/history_entry.dart';
import '../models/models.dart';
import '../services/archive_service.dart';
import '../services/content_repository.dart';
import '../services/library_service.dart';
import '../services/server_config_service.dart';
import '../services/tmdb_service.dart';
import 'mock_services.dart';

/// Ce que les écrans demandent au catalogue.
abstract class CatalogPort {
  Future<List<MediaItem>> search(String query);
  Future<List<MediaItem>> trending();

  /// Séries tendance (Accueil).
  Future<List<MediaItem>> trendingSeries();

  /// Films tendance (Accueil).
  Future<List<MediaItem>> trendingMovies();

  Future<MediaDetails> details(MediaItem item);
  Future<List<StreamSource>> streams(MediaItem item);
  Future<List<Episode>> seasonEpisodes(MediaItem item, int seasonNumber);
}

/// Adaptateur : expose le [ContentRepository] d'Edith comme [CatalogPort].
class RepositoryCatalog implements CatalogPort {
  RepositoryCatalog(this._repository);

  final ContentRepository _repository;

  @override
  Future<List<MediaItem>> search(String query) => _repository.search(query);

  @override
  Future<List<MediaItem>> trending() => _repository.trending();

  @override
  Future<List<MediaItem>> trendingSeries() async {
    final items = await _repository.trending();
    return items.where((item) => item.isSeries).toList();
  }

  @override
  Future<List<MediaItem>> trendingMovies() async {
    final items = await _repository.trending();
    return items.where((item) => !item.isSeries).toList();
  }

  @override
  Future<MediaDetails> details(MediaItem item) => _repository.details(item);

  @override
  Future<List<StreamSource>> streams(MediaItem item) =>
      _repository.streams(item);

  @override
  Future<List<Episode>> seasonEpisodes(MediaItem item, int seasonNumber) =>
      _repository.seasonEpisodes(item, seasonNumber);
}

/// Favoris et historique « Continuer à regarder » (stockage local).
abstract class LibraryService {
  Future<List<MediaItem>> favorites();
  Future<bool> isFavorite(String id);
  Future<void> toggleFavorite(MediaItem item);
  Future<List<HistoryEntry>> continueWatching();
  Future<void> recordProgress(
      MediaItem item, double progress, String positionLabel);
  Future<void> removeFromHistory(String id);
}

/// Lecteur vidéo intégré avec sous-titres. (Tadashi)
abstract class PlayerService {
  Future<void> play(StreamSource source, {MediaItem? item, Episode? episode});
}

/// Téléchargements avec pause / reprise. (Tadashi)
abstract class DownloadService {
  Future<List<DownloadItem>> downloads();
  Stream<List<DownloadItem>> watchDownloads();
  Future<void> start(StreamSource source, {MediaItem? item, Episode? episode});
  Future<void> pause(String id);
  Future<void> resume(String id);
  Future<void> cancel(String id);
}

/// Localisateur : les écrans utilisent ces champs, jamais les implémentations.
class AppServices {
  static CatalogPort catalog = MockCatalog();
  static LibraryService library = MockLibraryService();
  static PlayerService player = MockPlayerService();
  static DownloadService downloads = MockDownloadService();

  /// Service TMDB réel (null tant que [initRealServices] n'a pas tourné).
  static TmdbService? tmdb;

  /// Crée les vrais services d'Edith et bascule le catalogue et la
  /// bibliothèque dessus. En cas d'échec, les mocks restent en place.
  static Future<void> initRealServices() async {
    final serverService = await ServerConfigService.create();
    final tmdbService = TmdbService(
      apiKey: await serverService.getTmdbApiKey(),
    );
    final repository = ContentRepository(
      tmdb: tmdbService,
      archive: ArchiveService(),
      servers: serverService,
    );
    tmdb = tmdbService;
    catalog = RepositoryCatalog(repository);
    library = await LocalLibraryService.create();
  }

  static void configure({
    CatalogPort? catalog,
    LibraryService? library,
    PlayerService? player,
    DownloadService? downloads,
  }) {
    if (catalog != null) AppServices.catalog = catalog;
    if (library != null) AppServices.library = library;
    if (player != null) AppServices.player = player;
    if (downloads != null) AppServices.downloads = downloads;
  }
}
