/// Implémentations de DÉMONSTRATION des services PrinceMovie.
///
/// Données factices — uniquement pour faire tourner l'interface sans réseau
/// ni clé TMDB. Edith (catalogue, favoris, historique) et Tadashi (lecteur,
/// téléchargements) remplacent ces classes par les vraies implémentations
/// via `AppServices.configure()` / `AppServices.initRealServices()`.

import 'dart:async';

import '../models/download_item.dart';
import '../models/history_entry.dart';
import '../models/models.dart';
import 'app_services.dart';

const _series = <MediaItem>[
  MediaItem(
    id: 'tmdb:1',
    title: 'Lupin',
    type: MediaType.tv,
    year: 2021,
    genres: ['Action', 'Policier'],
    rating: 7.9,
    synopsis:
        'Assane Diop, gentleman cambrioleur inspiré par Arsène Lupin, '
        'veut venger son père, victime d\'une machination.',
  ),
  MediaItem(
    id: 'tmdb:2',
    title: 'VisionQuest',
    type: MediaType.tv,
    year: 2025,
    genres: ['Science-fiction'],
    rating: 8.1,
    synopsis:
        'Une équipe d\'explorateurs traque une technologie disparue '
        'capable de changer le monde.',
  ),
  MediaItem(
    id: 'tmdb:3',
    title: 'Lioness',
    type: MediaType.tv,
    year: 2023,
    genres: ['Action', 'Espionnage'],
    rating: 7.8,
    synopsis:
        'Une agente d\'élite infiltre un réseau terroriste au péril de sa vie.',
  ),
  MediaItem(
    id: 'tmdb:4',
    title: 'The Terminal List',
    type: MediaType.tv,
    year: 2022,
    genres: ['Action', 'Thriller'],
    rating: 8.0,
    synopsis:
        'Un ancien Navy SEAL enquête sur l\'embuscade qui a décimé son unité.',
  ),
];

const _movies = <MediaItem>[
  MediaItem(
    id: 'tmdb:5',
    title: 'Verity',
    type: MediaType.movie,
    year: 2025,
    genres: ['Thriller'],
    rating: 7.6,
    synopsis:
        'Une écrivaine en panne d\'inspiration découvre le manuscrit '
        'inachevé d\'une auteure blessée — et ses secrets.',
  ),
  MediaItem(
    id: 'tmdb:6',
    title: 'Hope',
    type: MediaType.movie,
    year: 2025,
    genres: ['Drame'],
    rating: 8.2,
    synopsis:
        'Une chirurgienne et une patiente que tout oppose apprennent à '
        'se faire confiance.',
  ),
  MediaItem(
    id: 'tmdb:7',
    title: 'Why Did I Get Married Again?',
    type: MediaType.movie,
    year: 2025,
    genres: ['Comédie'],
    rating: 6.9,
    synopsis:
        'Quatre couples d\'amis se retrouvent pour un week-end qui tourne '
        'à la mise au point générale.',
  ),
  MediaItem(
    id: 'tmdb:8',
    title: 'Runner',
    type: MediaType.movie,
    year: 2026,
    genres: ['Action'],
    rating: 7.4,
    synopsis:
        'Un coursier de nuit devient le témoin gênant d\'un trafic '
        'et doit fuir à travers la ville.',
  ),
  MediaItem(
    id: 'archive:mock-film',
    title: 'Le Voyage de la lune (domaine public)',
    type: MediaType.movie,
    year: 1902,
    genres: ['Domaine public'],
    rating: null,
    synopsis:
        'Film du domaine public — lecture et téléchargement directs '
        'depuis Internet Archive.',
  ),
];

List<MediaItem> get _allItems => [..._series, ..._movies];

MediaItem? _findById(String id) {
  for (final item in _allItems) {
    if (item.id == id) return item;
  }
  return null;
}

class MockCatalog implements CatalogPort {
  @override
  Future<List<MediaItem>> trending() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _allItems;
  }

  @override
  Future<List<MediaItem>> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    return _allItems
        .where((item) => item.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<MediaItem>> trendingSeries() async {
    final items = await trending();
    return items.where((item) => item.isTv).toList();
  }

  @override
  Future<List<MediaItem>> trendingMovies() async {
    final items = await trending();
    return items.where((item) => !item.isTv).toList();
  }

  @override
  Future<MediaDetails> details(MediaItem item) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final found = _findById(item.id) ?? _series.first;
    final isArchive = found.isArchive;
    final seasons = <Season>[];
    if (found.isTv) {
      for (var s = 1; s <= 3; s++) {
        seasons.add(
          Season(number: s, name: 'Saison $s', episodeCount: 8),
        );
      }
    }
    return MediaDetails(
      id: found.id,
      title: found.title,
      type: found.type,
      synopsis: found.synopsis,
      genres: found.genres,
      posterUrl: found.posterUrl,
      year: found.year,
      rating: found.rating,
      runtimeMinutes: found.isTv ? 50 : 115,
      seasons: seasons,
      source: isArchive ? 'Internet Archive' : 'TMDB',
      streams: isArchive
          ? const [
              StreamSource(
                url: 'https://example.com/mock/voyage-lune-720p.mp4',
                quality: StreamQuality.q720,
                source: 'Démo',
              ),
              StreamSource(
                url: 'https://example.com/mock/voyage-lune-480p.mp4',
                quality: StreamQuality.q480,
                source: 'Démo',
              ),
            ]
          : const [],
    );
  }

  @override
  Future<List<StreamSource>> streams(MediaItem item) async {
    final details = await this.details(item);
    return details.streams;
  }

  @override
  Future<List<Episode>> seasonEpisodes(
      MediaItem item, int seasonNumber) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List.generate(
      8,
      (i) => Episode(
        seasonNumber: seasonNumber,
        number: i + 1,
        title: 'Épisode ${i + 1}',
        durationMinutes: 45 + (i % 3) * 4,
      ),
    );
  }
}

class MockLibraryService implements LibraryService {
  final Set<String> _favoriteIds = {'tmdb:1', 'tmdb:5'};
  final List<HistoryEntry> _history = [
    HistoryEntry(
      item: _series[0],
      progress: 0.62,
      positionLabel: '18 min restantes',
    ),
    HistoryEntry(
      item: _movies[0],
      progress: 0.30,
      positionLabel: '1 h 18 restantes',
    ),
  ];

  @override
  Future<List<MediaItem>> favorites() async {
    return _allItems.where((i) => _favoriteIds.contains(i.id)).toList();
  }

  @override
  Future<bool> isFavorite(String id) async => _favoriteIds.contains(id);

  @override
  Future<void> toggleFavorite(MediaItem item) async {
    if (_favoriteIds.contains(item.id)) {
      _favoriteIds.remove(item.id);
    } else {
      _favoriteIds.add(item.id);
    }
  }

  @override
  Future<List<HistoryEntry>> continueWatching() async =>
      List.unmodifiable(_history);

  @override
  Future<void> recordProgress(
      MediaItem item, double progress, String positionLabel) async {
    _history.removeWhere((e) => e.item.id == item.id);
    _history.insert(
      0,
      HistoryEntry(
          item: item, progress: progress, positionLabel: positionLabel),
    );
  }

  @override
  Future<void> removeFromHistory(String id) async {
    _history.removeWhere((e) => e.item.id == id);
  }
}

class MockPlayerService implements PlayerService {
  @override
  Future<void> play(StreamSource source,
      {MediaItem? item, Episode? episode}) async {
    // Démonstration : le vrai lecteur (Tadashi) ouvrira la vidéo ici.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

class MockDownloadService implements DownloadService {
  final List<DownloadItem> _items = [
    const DownloadItem(
      id: 'dl-tmdb:1-s1e1',
      title: 'Lupin',
      episodeLabel: 'S1 E1',
      qualityLabel: '720p',
      progress: 0.45,
      status: DownloadStatus.downloading,
      sizeLabel: '1,2 Go',
    ),
    const DownloadItem(
      id: 'dl-tmdb:6',
      title: 'Hope',
      qualityLabel: '1080p',
      progress: 1.0,
      status: DownloadStatus.completed,
      sizeLabel: '2,4 Go',
    ),
  ];

  final StreamController<List<DownloadItem>> _controller =
      StreamController<List<DownloadItem>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_items));

  @override
  Future<List<DownloadItem>> downloads() async => List.unmodifiable(_items);

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    yield List.unmodifiable(_items);
    yield* _controller.stream;
  }

  @override
  Future<void> start(StreamSource source,
      {MediaItem? item, Episode? episode}) async {
    final id = 'dl-${item?.id ?? 'inconnu'}-${episode == null ? 'film' : 's${episode.seasonNumber ?? 1}e${episode.number}'}-${source.qualityLabel}';
    if (_items.any((d) => d.id == id)) return;
    _items.insert(
      0,
      DownloadItem(
        id: id,
        title: item?.title ?? 'Titre inconnu',
        episodeLabel: episode == null
            ? null
            : 'S${episode.seasonNumber ?? 1} E${episode.number}',
        qualityLabel: source.qualityLabel,
        progress: 0.0,
        status: DownloadStatus.queued,
        sizeLabel: '—',
      ),
    );
    _emit();
  }

  @override
  Future<void> pause(String id) async {
    _update(id, DownloadStatus.paused);
  }

  @override
  Future<void> resume(String id) async {
    _update(id, DownloadStatus.downloading);
  }

  @override
  Future<void> cancel(String id) async {
    _items.removeWhere((d) => d.id == id);
    _emit();
  }

  void _update(String id, DownloadStatus status) {
    final index = _items.indexWhere((d) => d.id == id);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(status: status);
    _emit();
  }
}
