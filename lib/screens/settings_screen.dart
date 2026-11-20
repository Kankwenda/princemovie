import 'package:flutter/material.dart';

import '../core/app_services.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/server_config_service.dart';

/// Paramètres : liste des serveurs (Edith) + clés API TMDB et
/// OpenSubtitles (stockées localement, jamais envoyées ailleurs).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _tmdbController = TextEditingController();
  final TextEditingController _osController = TextEditingController();
  final TextEditingController _customNameController = TextEditingController();
  final TextEditingController _customUrlController = TextEditingController();

  ServerConfigService? _service;
  List<ServerConfig> _servers = [];
  String _selectedServerId = 'tmdb';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tmdbController.dispose();
    _osController.dispose();
    _customNameController.dispose();
    _customUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = await ServerConfigService.create();
    final servers = await service.loadServers();
    final selected = await service.getSelectedServerId();
    final tmdbKey = await service.getTmdbApiKey() ?? '';
    final osKey = await service.getOpenSubtitlesApiKey() ?? '';
    if (!mounted) return;
    setState(() {
      _service = service;
      _servers = servers;
      _selectedServerId = selected;
      _tmdbController.text = tmdbKey;
      _osController.text = osKey;
      _loading = false;
    });
  }

  Future<void> _selectServer(String id) async {
    final service = _service;
    if (service == null) return;
    await service.setSelectedServerId(id);
    setState(() => _selectedServerId = id);
  }

  Future<void> _saveTmdbKey() async {
    final service = _service;
    if (service == null) return;
    final key = _tmdbController.text.trim();
    await service.setTmdbApiKey(key);
    AppServices.tmdb?.setApiKey(key);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé TMDB enregistrée localement.')),
    );
  }

  Future<void> _saveOsKey() async {
    final service = _service;
    if (service == null) return;
    await service.setOpenSubtitlesApiKey(_osController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Clé OpenSubtitles enregistrée localement.')),
    );
  }

  Future<void> _toggleServer(ServerConfig server, bool enabled) async {
    final service = _service;
    if (service == null) return;
    await service.updateServer(server.copyWith(enabled: enabled));
    await _load();
  }

  Future<void> _removeServer(ServerConfig server) async {
    final service = _service;
    if (service == null) return;
    await service.removeServer(server.id);
    await _load();
  }

  Future<void> _addCustomServer() async {
    final service = _service;
    if (service == null) return;
    final name = _customNameController.text.trim();
    final url = _customUrlController.text.trim();
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et adresse du serveur requis.')),
      );
      return;
    }
    try {
      await service.addServer(ServerConfig.custom(name: name, baseUrl: url));
    } on ArgumentError catch (e) {
      // Hôte bloqué (N3 Ultron) : on explique au lieu de planter.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }
    _customNameController.clear();
    _customUrlController.clear();
    await _load();
  }

  Future<void> _resetServers() async {
    final service = _service;
    if (service == null) return;
    await service.resetToDefaults();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Serveur des tendances',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choisis la source de l\'accueil : TMDB (films et séries) ou '
            'Internet Archive (films du domaine public).',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.card,
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'tmdb',
                  groupValue: _selectedServerId,
                  onChanged: (value) {
                    if (value != null) _selectServer(value);
                  },
                  title: const Text('TMDB'),
                  subtitle: const Text(
                    'Tendances films et séries',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  activeColor: AppTheme.gold,
                ),
                RadioListTile<String>(
                  value: 'archive',
                  groupValue: _selectedServerId,
                  onChanged: (value) {
                    if (value != null) _selectServer(value);
                  },
                  title: const Text('Internet Archive'),
                  subtitle: const Text(
                    'Films du domaine public, lisibles immédiatement',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  activeColor: AppTheme.gold,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Serveurs',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sources légales uniquement. Un serveur désactivé est ignoré '
            'par les recherches.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ..._servers.map(
            (server) => Card(
              color: AppTheme.card,
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                value: server.enabled,
                onChanged: (value) => _toggleServer(server, value),
                title: Text(server.name),
                subtitle: Text(
                  '${server.type.label} · ${server.baseUrl}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                activeColor: AppTheme.gold,
                secondary: server.isBuiltIn
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Supprimer',
                        onPressed: () => _removeServer(server),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Ajouter un serveur personnel',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'URL directe d\'une vidéo (MP4, MKV, WebM…). Les serveurs '
            'Jellyfin / Emby (adresse sans fichier) arrivent en v2.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customNameController,
            decoration: const InputDecoration(hintText: 'Nom (ex. Mon film)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customUrlController,
            decoration: const InputDecoration(
                hintText: 'Adresse (ex. https://mon-serveur.fr/film.mp4)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _addCustomServer,
            child: const Text('Ajouter le serveur'),
          ),
          TextButton(
            onPressed: _resetServers,
            child: const Text('Restaurer les serveurs par défaut'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Clé API TMDB',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clé gratuite sur themoviedb.org → Paramètres → API. '
            'Elle reste sur ton téléphone, envoyée uniquement à TMDB.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tmdbController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Colle ta clé TMDB ici',
              prefixIcon: Icon(Icons.key, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveTmdbKey,
            child: const Text('Enregistrer la clé TMDB'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Clé API OpenSubtitles',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Clé gratuite sur opensubtitles.com — pour les sous-titres '
            'des films TMDB. Gratuite et limitée en nombre par jour.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _osController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Colle ta clé OpenSubtitles ici',
              prefixIcon: Icon(Icons.key, color: AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveOsKey,
            child: const Text('Enregistrer la clé OpenSubtitles'),
          ),
          const SizedBox(height: 28),
          const Text(
            'À propos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('PrinceMovie — version 1.0.0'),
          const SizedBox(height: 8),
          const Text(
            'PrinceMovie utilise uniquement des sources légales (TMDB pour '
            'les métadonnées, Archive.org pour les contenus du domaine '
            'public). Le lecteur et les téléchargements ne portent que sur '
            'des contenus légaux ou fournis par l\'utilisateur.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
