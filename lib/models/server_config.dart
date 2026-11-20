// Configuration d'un serveur de contenu.
// Un serveur = un nom + une URL de base + un type. La liste est stockée
// en local (voir ServerConfigService) et modifiable dans les paramètres.
//
// Serveurs par défaut (pré-remplis) : TMDB (métadonnées) et Internet Archive
// (films du domaine public). L'utilisateur peut ajouter un serveur personnel
// (ex. son propre Jellyfin / Emby, ou une URL directe de fichier MP4).
//
// RÈGLE ABSOLUE : sources légales uniquement. Aucun serveur MovieBox,
// 4KHDHub, Dramachi ou autre source piratée ne doit jamais être ajouté ici.

/// Type de serveur.
enum ServerType {
  /// TMDB : métadonnées uniquement (affiches, synopsis, saisons).
  tmdb,

  /// Internet Archive : films du domaine public, vidéo directe.
  archive,

  /// YouTube : vidéos libres (chaînes officielles, Creative Commons).
  youtube,

  /// Serveur personnel (Jellyfin, Emby, URL directe de fichier...).
  custom,
}

extension ServerTypeExtension on ServerType {
  /// Libellé affiché dans l'interface.
  String get label {
    switch (this) {
      case ServerType.tmdb:
        return 'TMDB (métadonnées)';
      case ServerType.archive:
        return 'Internet Archive';
      case ServerType.youtube:
        return 'YouTube';
      case ServerType.custom:
        return 'Personnalisé';
    }
  }

  /// Valeur stockée en local.
  String get storageValue => name;

  static ServerType fromStorage(String? value) {
    switch (value) {
      case 'archive':
        return ServerType.archive;
      case 'youtube':
        return ServerType.youtube;
      case 'custom':
        return ServerType.custom;
      case 'tmdb':
      default:
        return ServerType.tmdb;
    }
  }
}

class ServerConfig {
  /// Identifiant unique stable (ex. 'builtin-tmdb', ou horodatage).
  final String id;

  /// Nom affiché dans les paramètres (ex. 'TMDB', 'Mon Jellyfin').
  final String name;

  /// URL de base du serveur (ex. 'https://api.themoviedb.org/3').
  final String baseUrl;

  /// Type de serveur.
  final ServerType type;

  /// Clé API éventuelle (TMDB, OpenSubtitles...). Nulle si non nécessaire.
  /// Stockée en local uniquement, jamais envoyée ailleurs que vers ce serveur.
  final String? apiKey;

  /// Faux = serveur ignoré par les recherches (sans être supprimé).
  final bool enabled;

  /// Vrai pour les serveurs pré-remplis (non supprimables).
  final bool isBuiltIn;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.type,
    this.apiKey,
    this.enabled = true,
    this.isBuiltIn = false,
  });

  /// Serveur TMDB par défaut (métadonnées uniquement).
  factory ServerConfig.tmdb() => const ServerConfig(
        id: 'builtin-tmdb',
        name: 'TMDB',
        baseUrl: 'https://api.themoviedb.org/3',
        type: ServerType.tmdb,
        isBuiltIn: true,
      );

  /// Serveur Internet Archive par défaut (domaine public).
  factory ServerConfig.archive() => const ServerConfig(
        id: 'builtin-archive',
        name: 'Internet Archive',
        baseUrl: 'https://archive.org',
        type: ServerType.archive,
        isBuiltIn: true,
      );

  /// Serveur personnel ajouté par l'utilisateur.
  factory ServerConfig.custom({
    required String name,
    required String baseUrl,
    String? apiKey,
  }) {
    return ServerConfig(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      baseUrl: baseUrl.trim(),
      type: ServerType.custom,
      apiKey: apiKey?.trim().isEmpty == true ? null : apiKey?.trim(),
    );
  }

  ServerConfig copyWith({
    String? name,
    String? baseUrl,
    ServerType? type,
    String? apiKey,
    bool? enabled,
  }) {
    return ServerConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      type: type ?? this.type,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      isBuiltIn: isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'type': type.storageValue,
        'apiKey': apiKey,
        'enabled': enabled,
        'isBuiltIn': isBuiltIn,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Serveur',
        baseUrl: json['baseUrl'] as String? ?? '',
        type: ServerTypeExtension.fromStorage(json['type'] as String?),
        apiKey: json['apiKey'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      );
}
