import 'media_details.dart';
import 'media_item.dart';
import 'stream_source.dart';

/// Média prêt pour le lecteur (Tadashi) : un élément + ses sources vidéo
/// légales directes.
///
/// Construit depuis une fiche détail par
/// [PlayableMedia.fromMediaDetails] (utilisé par le lecteur, via
/// `RepositoryCatalog` / `media_actions.dart`),
/// ou à la main par le lecteur quand les sources ont été résolues ailleurs
/// (ex. `media_actions.dart`).
///
/// SOURCES LÉGALES UNIQUEMENT : les sources viennent d'Archive.org
/// (domaine public) ou du serveur personnel de l'utilisateur. TMDB ne
/// fournit que des métadonnées, jamais de flux.
class PlayableMedia {
  const PlayableMedia({
    required this.item,
    required this.sources,
    this.initialSource,
    this.seasonNumber,
    this.episodeNumber,
  });

  /// Élément lu (titre, affiche, métadonnées).
  final MediaItem item;

  /// Sources vidéo directes, triées de la meilleure à la moins bonne
  /// qualité. Vide = aucune lecture possible (ex. fiche TMDB sans flux).
  final List<StreamSource> sources;

  /// Source à lire en premier (sinon la première de [sources]).
  final StreamSource? initialSource;

  /// Numéro de la saison lue (épisodes de série).
  final int? seasonNumber;

  /// Numéro de l'épisode lu (épisodes de série).
  final int? episodeNumber;

  /// Média prêt pour le lecteur depuis une fiche détail.
  factory PlayableMedia.fromMediaDetails(
    MediaDetails details, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return PlayableMedia(
      item: details.item,
      sources: details.streams,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  /// Vrai si au moins une source vidéo directe est disponible.
  bool get hasPlayableSource => sources.isNotEmpty;

  /// Source de la qualité demandée ('1080p', '720p', '480p', 'Source'),
  /// ou la meilleure disponible si elle n'existe pas (null si aucune).
  StreamSource? sourceForQuality(String label) {
    for (final source in sources) {
      if (source.qualityLabel == label) return source;
    }
    return sources.isEmpty ? null : sources.first;
  }
}
