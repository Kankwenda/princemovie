import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/theme.dart';
import '../models/models.dart';

/// Téléchargements : liste avec pause / reprise et progression.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  String _statusLabel(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return 'En attente';
      case DownloadStatus.downloading:
        return 'Téléchargement…';
      case DownloadStatus.paused:
        return 'En pause';
      case DownloadStatus.completed:
        return 'Terminé';
      case DownloadStatus.failed:
        return 'Échec';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Téléchargements')),
      body: StreamBuilder<List<DownloadItem>>(
        stream: AppServices.downloads.watchDownloads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <DownloadItem>[];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download, size: 48, color: AppTheme.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'Aucun téléchargement.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Téléchargez un film ou un épisode depuis sa fiche.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final isActive = item.status == DownloadStatus.downloading;
              final isPaused = item.status == DownloadStatus.paused;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.movie, color: AppTheme.gold),
                ),
                title: Text(
                  item.episodeLabel == null
                      ? item.title
                      : '${item.title} — ${item.episodeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: item.progress,
                      backgroundColor: AppTheme.surface,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_statusLabel(item.status)} · ${item.qualityLabel} · '
                      '${item.sizeLabel} · ${(item.progress * 100).round()} %',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      IconButton(
                        icon: const Icon(Icons.pause),
                        tooltip: 'Pause',
                        onPressed: () =>
                            AppServices.downloads.pause(item.id),
                      ),
                    if (isPaused)
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Reprendre',
                        onPressed: () =>
                            AppServices.downloads.resume(item.id),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Supprimer',
                      onPressed: () =>
                          AppServices.downloads.cancel(item.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
