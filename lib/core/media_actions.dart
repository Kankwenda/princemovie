/// Actions Lecture / Télécharger partagées par les écrans.
///
/// Règle d'honnêteté : TMDB ne fournit que des métadonnées, jamais de flux.
/// Quand un titre n'a aucune source vidéo directe, on l'explique au lieu
/// de faire semblant de lire ou de télécharger.

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_services.dart';

const String _noStreamMessage =
    'Lecture non disponible pour ce titre : TMDB ne fournit que des '
    'métadonnées. Choisis un film du domaine public (Internet Archive).';

/// Choisit la meilleure source disponible (ou celle de la qualité demandée).
StreamSource? _pickSource(List<StreamSource> streams, StreamQuality? quality) {
  if (streams.isEmpty) return null;
  if (quality != null) {
    for (final source in streams) {
      if (source.quality == quality) return source;
    }
  }
  return streams.first;
}

void _showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Lance la lecture de la meilleure source disponible.
Future<void> playBestAvailable(
  BuildContext context,
  MediaItem item, {
  StreamQuality? quality,
  Episode? episode,
}) async {
  final streams = await AppServices.catalog.streams(item);
  final source = _pickSource(streams, quality);
  if (source == null) {
    _showMessage(context, _noStreamMessage);
    return;
  }
  await AppServices.player.play(source, item: item, episode: episode);
  _showMessage(
    context,
    'Lecture de ${item.title} (${source.qualityLabel}).',
  );
}

/// Ajoute la meilleure source disponible aux téléchargements.
Future<void> downloadBestAvailable(
  BuildContext context,
  MediaItem item, {
  StreamQuality? quality,
  Episode? episode,
}) async {
  final streams = await AppServices.catalog.streams(item);
  final source = _pickSource(streams, quality);
  if (source == null) {
    _showMessage(context, _noStreamMessage);
    return;
  }
  await AppServices.downloads.start(source, item: item, episode: episode);
  _showMessage(
    context,
    episode == null
        ? '${item.title} ajouté aux téléchargements.'
        : '${item.title} — Épisode ${episode.number} ajouté aux téléchargements.',
  );
}
