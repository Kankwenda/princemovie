/// Élément téléchargé (ou en cours de téléchargement).
///
/// Modèle d'interface pour l'écran Téléchargements — le moteur de
/// téléchargement (pause/reprise, fichiers) est à Tadashi.

enum DownloadStatus { queued, downloading, paused, completed, failed }

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.title,
    required this.qualityLabel,
    required this.progress,
    required this.status,
    required this.sizeLabel,
    this.episodeLabel,
  });

  final String id;
  final String title;

  /// Ex. « S1 E1 » — null pour un film.
  final String? episodeLabel;

  /// Libellé de qualité : « 1080p », « 720p », « 480p », « Source ».
  final String qualityLabel;

  /// 0.0 à 1.0.
  final double progress;
  final DownloadStatus status;

  /// Ex. « 1,2 Go ».
  final String sizeLabel;

  DownloadItem copyWith({double? progress, DownloadStatus? status}) {
    return DownloadItem(
      id: id,
      title: title,
      qualityLabel: qualityLabel,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      sizeLabel: sizeLabel,
      episodeLabel: episodeLabel,
    );
  }
}
