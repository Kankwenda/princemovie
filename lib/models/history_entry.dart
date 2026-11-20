import 'media_item.dart';

/// Entrée de l'historique « Continuer à regarder » (stockage local).
class HistoryEntry {
  const HistoryEntry({
    required this.item,
    required this.progress,
    required this.positionLabel,
  });

  final MediaItem item;

  /// 0.0 à 1.0.
  final double progress;

  /// Ex. « 18 min restantes ».
  final String positionLabel;

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'progress': progress,
        'positionLabel': positionLabel,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        item: MediaItem.fromJson(
          (json['item'] as Map).cast<String, dynamic>(),
        ),
        progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
        positionLabel: json['positionLabel'] as String? ?? '',
      );
}
