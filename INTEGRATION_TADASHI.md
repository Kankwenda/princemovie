# Intégration — Lecteur, téléchargements, stockage local (Tadashi)

## Fichiers créés (partie Tadashi)

| Fichier | Rôle |
|---|---|
| `lib/player/video_player_screen.dart` | `PlayerScreen` : chewie + video_player, qualité, sous-titres .srt, reprise de lecture, lecture hors-ligne, bouton téléchargement |
| `lib/player/video_player_service.dart` | `VideoPlayerService implements PlayerService` : résout les sources, priorise le fichier téléchargé, pousse `PlayerScreen` |
| `lib/player/srt_parser.dart` | `SrtParser.parse` : texte .srt → liste `Subtitle` (chewie) |
| `lib/player/source_selectors.dart` | `QualitySelectorSheet`, `SubtitleSelectorSheet` (bottom sheets, thème sombre / doré) |
| `lib/models/playable_media.dart` | `PlayableMedia` : élément + sources légales + source initiale + saison/épisode |
| `lib/services/download_service.dart` | `DownloadManager implements DownloadService` : pause/reprise HTTP Range, persistance, fichiers app |
| `lib/core/format.dart` | `formatBytes` (« 1,2 Go »), `formatDuration` |
| `lib/core/legal_sources.dart` | `isLegalSourceUrl` / `requireLegalSource` : bloque MovieBox, api.inmoviebox.com, 4KHDHub, Dramachi |
| `lib/core/service_contracts.dart` | Réexport de `app_services.dart` (compatibilité des imports existants) — **ne plus toucher** (coordination Friday) |

Fichiers modifiés par Tadashi (coutures uniquement) : `lib/core/app_services.dart`
(trendingSeries/trendingMovies ajoutés au contrat), `lib/models/history_entry.dart`
(toJson/fromJson ajoutés), `lib/services/library_service.dart` (import corrigé),
`lib/core/mock_services.dart` (réécrit sur les nouveaux contrats).

## Branchement (main.dart — à Jarvis)

```dart
import 'package:princemovie/player/video_player_service.dart';
import 'package:princemovie/services/download_service.dart';

// 1. Clé de navigation du lecteur :
MaterialApp(
  navigatorKey: VideoPlayerService.navigatorKey,
  ...
)

// 2. Après AppServices.initRealServices() :
AppServices.configure(
  player: VideoPlayerService(),
  downloads: DownloadManager(),
);
```

Sans la clé de navigation, `play()` lève un `StateError` explicite.

## Packages requis — aucun ajout

Déjà dans `pubspec.yaml` : `video_player ^2.14.1`, `chewie ^1.18.1`,
`http ^1.6.0`, `path_provider ^2.1.6`, `shared_preferences ^2.5.6`.
**Pas de dio** : les téléchargements utilisent `package:http` + en-tête `Range`.

## Contrats implémentés (core/app_services.dart)

- `PlayerService.play(StreamSource source, {MediaItem? item, Episode? episode})`
- `DownloadService` : `downloads()`, `watchDownloads()`, `start(source, {item, episode})`,
  `pause(id)`, `resume(id)`, `cancel(id)` — id : `dl-<mediaId>-<film|sNeM>-<qualité>`
- Stockage local : `LibraryService` d'Edith (`LocalLibraryService`,
  SharedPreferences) — favoris + « Continuer à regarder » ; le lecteur
  enregistre la progression via `recordProgress(item, fraction, label)` toutes
  les 5 s, à la pause et à la fermeture, et la restaure depuis `continueWatching()`.

## Modèles canoniques utilisés (vérifiés 20 nov. ~17h20)

- `MediaItem` : `id, title, type (MediaType {movie, tv}), year (int?),
  genres, rating (double?), synopsis (String?), posterUrl (String?)`.
  **Plus de `overview`, `posterTop`/`posterBottom`** — l'élément minimal du
  lecteur se construit avec `id, title, type` uniquement.
- `StreamSource` : `url, quality (StreamQuality), language?, subtitleUrl?,
  format, source, sizeBytes?` + `qualityLabel`.
- `Episode` : `seasonNumber?, number, title?, durationMinutes (int?),
  synopsis?, stillUrl?, airDate?`.
- `DownloadItem` : `id, title, episodeLabel?, qualityLabel, progress,
  status (DownloadStatus {queued, downloading, paused, completed, failed}),
  sizeLabel`.
- `SubtitleFile.fromDirectUrl(url, {language})`, `SubtitleService.fetchSrtText(url)`.
- `MediaDetails.item` reconstruit le `MediaItem` ; `PlayableMedia.fromMediaDetails(details)`.

## Règle légale (absolue)

Lecteur et téléchargements ne servent que des sources légales (Archive.org
domaine public, fichiers personnels, serveur personnel). `DownloadManager.start`
rejette toute URL MovieBox / inmoviebox / 4KHDHub / Dramachi (`ArgumentError`).
TMDB = métadonnées uniquement, jamais de flux.

## Limites connues (à vérifier au premier `flutter build`)

- API chewie 1.18 (`subtitle`, `additionalOptions`, `OptionItem`,
  `isFullScreen`) utilisée selon la documentation standard — à confirmer à la
  compilation (Flutter non installé sur la VM, code non compilé).
- Au changement de qualité, les sous-titres de la source précédente restent
  affichés si la nouvelle source n'en fournit pas (même média : même contenu
  en pratique).
- Écrans Téléchargements / Favoris : déjà construits par Friday (contrats
  respectés) ; non réécrits par Tadashi.
