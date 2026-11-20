# PrinceMovie

Application Android Flutter — catalogue de films et séries, **sources légales
uniquement** : métadonnées TMDB, films du domaine public (Archive.org).
Aucun endpoint piraté (ni MovieBox, ni 4KHDHub, ni Dramachi) — le lecteur et
les téléchargements ne portent que sur des contenus légaux ou fournis par
l'utilisateur.

## Identité

- Nom : **PrinceMovie** — package `com.princemovie.app`
- Thème sombre : fond `#0B0B0F`, cartes `#17171E`, accent doré `#D4AF37`
- Logo : « P » doré sur fond noir (`assets/images/logo.png`, icône adaptative
  Android générée par `tools/make_icons.py`)

## Structure

```
lib/
  main.dart               Point d'entrée (branchement services Edith) + onglets (4)
  core/
    theme.dart            Thème sombre + couleurs de marque (AppTheme)
    app_services.dart     Contrats : CatalogPort, LibraryService,
                          PlayerService, DownloadService + AppServices
    service_contracts.dart  Ré-export de app_services.dart (compatibilité)
    mock_services.dart    Implémentations de démonstration (données factices)
    media_actions.dart    Lecture / Télécharger (meilleure source dispo)
    legal_sources.dart    Garde-fou : bloque les hôtes pirates
    format.dart           formatBytes, formatDuration
  models/                 (Edith — canonique, fichiers séparés)
    media_item.dart       MediaItem, MediaType
    media_details.dart    MediaDetails, Season
    episode.dart          Episode
    download_item.dart    DownloadItem, DownloadStatus
    history_entry.dart    HistoryEntry
    server_config.dart    ServerConfig + ServerType
    stream_source.dart    StreamSource + StreamQuality
    subtitle.dart         SubtitleFile
    playable_media.dart   PlayableMedia / VideoSource / SubtitleTrack (lecteur)
    media.dart            Barrel : ré-exporte les modèles de base
    models.dart           Export unique
  services/               (Edith — ne pas modifier)
    tmdb_service.dart     TMDB : métadonnées uniquement, jamais de flux
    archive_service.dart  Archive.org : domaine public, vidéo directe
    content_repository.dart  Façade : search / trending / details / streams
    library_service.dart  LocalLibraryService (favoris + historique, local)
    server_config_service.dart  Serveurs + clés API (stockage local)
    subtitle_service.dart OpenSubtitles + .srt directs
    services.dart         Barrel des services
  player/                 (Tadashi)
    source_selectors.dart Feuilles de choix qualité / sous-titres
    srt_parser.dart       Analyse des fichiers .srt
  widgets/
    poster.dart           Vraie affiche (TMDB/Archive) ou dégradé de repli
    media_card.dart       Carte d'affiche + rangée horizontale
    section_header.dart   Titre de section + « Tous > »
  screens/
    home_screen.dart      Bannière, Continuer à regarder, Séries/Films Tendance
    search_screen.dart    Recherche + grille de résultats
    detail_screen.dart    Affiche, synopsis, saisons/épisodes, Lecture/Télécharger/Favori
    downloads_screen.dart Liste des téléchargements (pause/reprise)
    favorites_screen.dart Favoris + historique « Continuer à regarder »
    settings_screen.dart  Serveur des tendances, serveurs, clés API TMDB/OpenSubtitles
android/                  Manifeste, icônes adaptatives, Gradle
.github/workflows/build-apk.yml  Build APK via GitHub Actions
tools/make_icons.py       Génère logo + icônes (PIL)
```

## Compiler l'APK

### Via GitHub Actions (recommandé)

1. Pousser le projet sur GitHub (branche `main`).
2. L'action **Build APK** se lance automatiquement (ou manuellement :
   onglet Actions → Build APK → Run workflow).
3. Télécharger l'artefact `princemovie-apk` → `app-release.apk`.

### En local (si Flutter est installé)

```sh
flutter pub get
flutter analyze
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk
```

Pour régénérer les icônes : `python3 tools/make_icons.py`.

## Configuration

Ouvrir **Paramètres** dans l'appli (icône ⚙️ sur l'Accueil) :

1. Choisir le serveur des tendances (TMDB ou Internet Archive).
2. Activer/désactiver les serveurs, ajouter un serveur personnel :
   une URL directe de fichier vidéo (MP4, MKV, WebM…) — la recherche
   la retrouve par son nom, la fiche permet Lecture et Téléchargement.
   Les adresses Jellyfin / Emby sans fichier direct ne sont pas
   lisibles en v1 (support prévu en v2).
3. Coller la clé API TMDB gratuite (compte gratuit sur
   https://www.themoviedb.org/settings/api) — stockée localement,
   envoyée uniquement à TMDB. Sans clé, les tendances se replient sur
   les films Archive.org les plus téléchargés.
4. Coller la clé OpenSubtitles (optionnel, pour les sous-titres).

## Règles d'honnêteté appliquées dans l'interface

- TMDB ne fournit que des métadonnées : sur une fiche sans source vidéo
  directe, **Lecture** et **Télécharger** sont désactivés et l'écran
  l'explique (« Métadonnées TMDB uniquement »).
- Les qualités proposées (1080p / 720p / 480p) viennent des sources
  réelles (`MediaDetails.streams` → `StreamQuality`), jamais d'une liste
  inventée.
- Pas de badge « En français » : la langue audio n'est pas connue dans
  les modèles (TMDB ne la fournit pas) — les affiches affichent un
  dégradé de repli quand aucune image n'est disponible.

## Interfaces de services (noms convenus — équipe)

Les écrans appellent `AppServices` (`lib/core/app_services.dart`) :

| Port / service | Méthodes | Propriétaire |
|---|---|---|
| `CatalogPort` | `search(query)`, `trending()`, `trendingSeries()`, `trendingMovies()`, `details(item)`, `streams(item)`, `seasonEpisodes(item, seasonNumber)` | Edith (`RepositoryCatalog` adapte `ContentRepository`) |
| `LibraryService` | `favorites()`, `isFavorite(id)`, `toggleFavorite(item)`, `continueWatching()`, `recordProgress(item, progress, positionLabel)`, `removeFromHistory(id)` | Edith (`LocalLibraryService`) |
| `PlayerService` | `play(source, {item, episode})` | Tadashi (lecteur + sous-titres) |
| `DownloadService` | `downloads()`, `watchDownloads()`, `start(source, {item, episode})`, `pause(id)`, `resume(id)`, `cancel(id)` | Tadashi (téléchargement pause/reprise) |
| `ContentRepository` (façade) | `search`, `trending`, `details(item)`, `streams(item)`, `seasonEpisodes(item, n)` (+ champs `tmdb`, `archive`, `servers`) | Edith |
| `ServerConfigService` | `loadServers()`, `saveServers()`, `addServer()`, `updateServer()`, `removeServer()`, `resetToDefaults()`, `enabledServers()`, `getSelectedServerId()`, `setSelectedServerId()`, `getTmdbApiKey()`, `setTmdbApiKey()`, `getOpenSubtitlesApiKey()`, `setOpenSubtitlesApiKey()` — création par `ServerConfigService.create()` | Edith |
| `SubtitleService` | `search({tmdbId, query, languages})`, `downloadLink(fileId)`, `fetchSrtText(url)` | Edith |
| `PlayableMedia` / `VideoSource` / `SubtitleTrack` | Contrat lecteur : `PlayableMedia.fromMediaDetails(details, {seasonNumber, episodeNumber})` | Tadashi |

Pour brancher les vrais lecteur / téléchargements : `AppServices.configure(
player: …, downloads: …)` dans `main()`. En attendant, des mocks font
tourner l'interface. `main()` branche déjà le vrai catalogue et la vraie
bibliothèque d'Edith ; en cas d'échec, le catalogue de démonstration
reste en place.

## Équipe

- **Friday** : squelette + interface (`main.dart`, `core/`, `widgets/`,
  `screens/`, `android/`, workflow, icônes)
- **Edith** : `lib/models/` + `lib/services/` — TMDB / Archive.org,
  favoris, historique
- **Tadashi** : `lib/player/` — lecteur vidéo + téléchargements
- **Ultron** : vérification
