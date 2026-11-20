/// Garde-fou « sources légales uniquement ».
///
/// La règle du projet : PrinceMovie ne lit et ne télécharge que des
/// contenus légaux (Archive.org / domaine public, fichiers personnels,
/// serveur personnel de l'utilisateur).
///
/// Ce fichier bloque les hôtes connus des services pirates (MovieBox,
/// 4KHDHub, Dramachi). C'est un filet de sécurité, pas une liste blanche :
/// l'application ne doit de toute façon jamais recevoir d'URL venant de
/// ces services.

/// Hôtes interdits (comparaison en « contient », insensible à la casse).
const List<String> _blockedHosts = [
  'moviebox',
  'inmoviebox',
  '4khdhub',
  'dramachi',
];

/// Vrai si l'URL peut être utilisée par le lecteur / les téléchargements.
///
/// - `false` pour une URL invalide, sans schéma, ou d'un hôte bloqué ;
/// - `true` pour http/https (et file://) hors liste de blocage.
bool isLegalSourceUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'file') {
    return false;
  }
  final host = uri.host.toLowerCase();
  for (final blocked in _blockedHosts) {
    if (host.contains(blocked)) return false;
  }
  return true;
}

/// Lève [ArgumentError] si l'URL est interdite. À appeler avant toute
/// lecture ou tout téléchargement d'une source réseau.
void requireLegalSource(String url) {
  if (!isLegalSourceUrl(url)) {
    throw ArgumentError(
      'Source non autorisée : $url. PrinceMovie ne sert que des sources '
      'légales (Archive.org, fichiers personnels, serveur personnel).',
    );
  }
}
