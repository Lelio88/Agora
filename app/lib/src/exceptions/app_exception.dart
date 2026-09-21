/// Hiérarchie scellée des erreurs métier d'Agora.
///
/// Les couches `data/` traduisent les erreurs de transport (Supabase,
/// PostgREST, réseau) en sous-classes de [AppException] ; l'interface ne voit
/// jamais une `PostgrestException` brute. `sealed` rend le `switch` des
/// messages exhaustif : ajouter un cas sans son texte ne compile pas.
///
/// Invariant : deux échecs que le serveur rend volontairement
/// indiscernables (compte inexistant / mauvais mot de passe) partagent le même
/// message côté interface.
library;

sealed class AppException implements Exception {
  const AppException(this.code, this.message);

  /// Identifiant stable, indépendant de la langue.
  final String code;

  /// Message technique pour les logs — l'interface passe par la l10n.
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Repli quand aucune traduction plus précise n'existe.
final class UnknownException extends AppException {
  const UnknownException() : super('unknown', 'Something went wrong');
}
