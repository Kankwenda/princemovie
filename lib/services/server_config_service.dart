// Stockage local de la liste des serveurs et des clés API.
// Utilise shared_preferences (simple clé/valeur, suffisant ici).
// La liste est pré-remplie avec TMDB + Internet Archive au premier lancement.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/legal_sources.dart';
import '../models/models.dart';

class ServerConfigService {
  /// Clé de stockage de la liste des serveurs (JSON).
  static const String serversKey = 'princemovie_servers_v1';

  /// Clé de stockage de la clé API TMDB.
  /// Même clé que l'écran Paramètres (settings_screen.dart) : 'tmdb_api_key'.
  static const String tmdbApiKeyKey = 'tmdb_api_key';

  /// Clé de stockage du serveur sélectionné dans les paramètres
  /// ('tmdb' ou 'archive'). Même clé que l'écran Paramètres.
  static const String selectedServerKey = 'selected_server';

  /// Clé de stockage de la clé API OpenSubtitles.
  static const String openSubtitlesApiKeyKey =
      'princemovie_opensubtitles_api_key';

  final SharedPreferences _prefs;

  ServerConfigService(this._prefs);

  /// Crée le service (charge SharedPreferences). À appeler au démarrage.
  static Future<ServerConfigService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ServerConfigService(prefs);
  }

  /// Serveurs par défaut : TMDB (métadonnées) + Internet Archive.
  static List<ServerConfig> defaultServers() => [
        ServerConfig.tmdb(),
        ServerConfig.archive(),
      ];

  // ---------------------------------------------------------------------------
  // Liste des serveurs
  // ---------------------------------------------------------------------------

  /// Charge la liste des serveurs. Au premier lancement, renvoie les
  /// serveurs par défaut et les enregistre.
  Future<List<ServerConfig>> loadServers() async {
    final raw = _prefs.getString(serversKey);
    if (raw == null || raw.isEmpty) {
      final defaults = defaultServers();
      await saveServers(defaults);
      return defaults;
    }
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ServerConfig.fromJson)
          .toList();
    } catch (_) {
      // Données corrompues : on repart des serveurs par défaut.
      return defaultServers();
    }
  }

  /// Enregistre la liste complète des serveurs.
  Future<void> saveServers(List<ServerConfig> servers) async {
    final raw = jsonEncode(servers.map((s) => s.toJson()).toList());
    await _prefs.setString(serversKey, raw);
  }

  /// Ajoute un serveur (ex. Jellyfin/Emby personnel, URL directe MP4).
  /// Refuse les hôtes pirates connus (MovieBox, 4KHDHub, Dramachi...).
  Future<void> addServer(ServerConfig server) async {
    requireLegalSource(server.baseUrl);
    final servers = await loadServers();
    servers.add(server);
    await saveServers(servers);
  }

  /// Met à jour un serveur existant (recherche par [id]).
  /// Valide la nouvelle adresse comme à l'ajout (N2 Ultron) : un
  /// contournement du garde-fou via la modification est refusé.
  Future<void> updateServer(ServerConfig server) async {
    requireLegalSource(server.baseUrl);
    final servers = await loadServers();
    final index = servers.indexWhere((s) => s.id == server.id);
    if (index == -1) return;
    servers[index] = server;
    await saveServers(servers);
  }

  /// Supprime un serveur par son [id]. Les serveurs intégrés (TMDB,
  /// Archive) ne sont pas supprimables : désactivez-les plutôt.
  Future<void> removeServer(String id) async {
    final servers = await loadServers();
    servers.removeWhere((s) => s.id == id && !s.isBuiltIn);
    await saveServers(servers);
  }

  /// Restaure les serveurs par défaut (TMDB + Internet Archive).
  Future<void> resetToDefaults() async => saveServers(defaultServers());

  /// Serveurs activés uniquement.
  Future<List<ServerConfig>> enabledServers() async {
    final servers = await loadServers();
    return servers.where((s) => s.enabled).toList();
  }

  /// Identifiant du serveur sélectionné dans les paramètres
  /// ('tmdb' ou 'archive', 'tmdb' par défaut).
  Future<String> getSelectedServerId() async =>
      _prefs.getString(selectedServerKey) ?? 'tmdb';

  /// Enregistre le serveur sélectionné dans les paramètres.
  Future<void> setSelectedServerId(String serverId) async {
    await _prefs.setString(selectedServerKey, serverId);
  }

  // ---------------------------------------------------------------------------
  // Clés API (stockées en local uniquement)
  // ---------------------------------------------------------------------------

  /// Clé API TMDB saisie par l'utilisateur (nulle si non saisie).
  Future<String?> getTmdbApiKey() async => _prefs.getString(tmdbApiKeyKey);

  /// Enregistre la clé API TMDB.
  Future<void> setTmdbApiKey(String key) async {
    await _prefs.setString(tmdbApiKeyKey, key.trim());
  }

  /// Clé API OpenSubtitles saisie par l'utilisateur (nulle si non saisie).
  Future<String?> getOpenSubtitlesApiKey() async =>
      _prefs.getString(openSubtitlesApiKeyKey);

  /// Enregistre la clé API OpenSubtitles.
  Future<void> setOpenSubtitlesApiKey(String key) async {
    await _prefs.setString(openSubtitlesApiKeyKey, key.trim());
  }
}
