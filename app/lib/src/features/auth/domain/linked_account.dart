/// Un compte d'un fournisseur (Google…) relié à celui d'Agora : on peut se
/// connecter avec lui.
///
/// Choix non évident : [isOnlyWayIn] vient du nombre d'identités du compte.
/// Un compte ouvert par Google n'a que celle-là (ni mot de passe, ni autre
/// fournisseur) ; GoTrue refuse de la délier, et l'écran n'offre pas de le
/// faire.
library;

final class LinkedAccount {
  const LinkedAccount({required this.label, required this.isOnlyWayIn});

  /// L'adresse du compte, à défaut son nom.
  final String label;

  /// Le seul moyen de se connecter à ce compte Agora.
  final bool isOnlyWayIn;
}
