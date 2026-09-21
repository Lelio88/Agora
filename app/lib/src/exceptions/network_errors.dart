/// Reconnaît une panne réseau dans le texte d'une erreur, pour les couches
/// `data/`.
///
/// Choix non évident : on lit le texte plutôt que le type, pour deux raisons.
/// `SocketException` vient de `dart:io`, absent du web. Et supabase_flutter
/// emballe souvent la panne dans une `AuthException` dont seul le message
/// garde la trace (`ClientException with SocketException…`). Le texte est le
/// seul signal commun à Android, au web et aux versions du SDK.
library;

const _networkMarkers = [
  'socketexception',
  'clientexception',
  'connection refused',
  'connection closed',
  'connection reset',
  'failed host lookup',
  'handshakeexception',
  'timeoutexception',
  'timed out',
  'network is unreachable',
  'xmlhttprequest error',
  'failed to fetch',
];

bool looksLikeNetworkError(String text) {
  final lower = text.toLowerCase();
  return _networkMarkers.any(lower.contains);
}
