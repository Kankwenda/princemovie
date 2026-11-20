// Favoris et historique « Continuer à regarder » : implémentation de
// [LibraryService] (voir core/app_services.dart) en stockage local
// (SharedPreferences, JSON). À passer à AppServices.configure(library: ...)
// dans main().

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_services.dart';
import '../models/media.dart';

class LocalLibraryService implements LibraryService {
  /// Clé de stockage des favoris (JSON : liste de MediaItem).
  static const String favoritesKey = 'princemovie_favorites_v1';

  /// Clé de stockage de l'historique (JSON : liste de HistoryEntry).
  static const String historyKey = 'princemovie_history_v1';

  /// Nombre maximum d'entrées gardées dans « Continuer à regarder ».
  static const int maxHistoryEntries = 20;

  final SharedPreferences _prefs;

  LocalLibraryService(this._prefs);

  /// Crée le service (charge SharedPreferences). À appeler au démarrage.
  static Future<LocalLibraryService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalLibraryService(prefs);
  }

  // ---------------------------------------------------------------------------
  // Favoris
  // ---------------------------------------------------------------------------

  @override
  Future<List<MediaItem>> favorites() async {
    return _loadItems(favoritesKey, MediaItem.fromJson);
  }

  @override
  Future<bool> isFavorite(String id) async {
    final items = await favorites();
    return items.any((item) => item.id == id);
  }

  @override
  Future<void> toggleFavorite(MediaItem item) async {
    final items = await favorites();
    final index = items.indexWhere((i) => i.id == item.id);
    if (index == -1) {
      items.add(item);
    } else {
      items.removeAt(index);
    }
    await _saveItems(favoritesKey, items);
  }

  // ---------------------------------------------------------------------------
  // Historique « Continuer à regarder »
  // ---------------------------------------------------------------------------

  @override
  Future<List<HistoryEntry>> continueWatching() async {
    return _loadItems(historyKey, HistoryEntry.fromJson);
  }

  @override
  Future<void> recordProgress(
      MediaItem item, double progress, String positionLabel) async {
    final entries = await continueWatching();
    final clamped = progress.clamp(0.0, 1.0);
    entries.removeWhere((e) => e.item.id == item.id);
    entries.insert(
      0,
      HistoryEntry(
        item: item,
        progress: clamped,
        positionLabel: positionLabel,
      ),
    );
    final trimmed = entries.length > maxHistoryEntries
        ? entries.sublist(0, maxHistoryEntries)
        : entries;
    await _saveItems(historyKey, trimmed);
  }

  @override
  Future<void> removeFromHistory(String id) async {
    final entries = await continueWatching();
    entries.removeWhere((e) => e.item.id == id);
    await _saveItems(historyKey, entries);
  }

  // ---------------------------------------------------------------------------
  // Lecture / écriture JSON
  // ---------------------------------------------------------------------------

  Future<List<T>> _loadItems<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } catch (_) {
      return <T>[];
    }
  }

  Future<void> _saveItems<T extends Object>(
    String key,
    List<T> items,
  ) async {
    final raw = jsonEncode(
      items.map((item) {
        final map = (item as dynamic).toJson() as Map<String, dynamic>;
        return map;
      }).toList(),
    );
    await _prefs.setString(key, raw);
  }
}
