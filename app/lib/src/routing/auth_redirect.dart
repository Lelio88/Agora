/// Règle de redirection selon la session, isolée du routeur pour être testée
/// seule.
///
/// Invariant : `/reset-password` reste ouvert aux deux états. Vérifier le code
/// de réinitialisation ouvre une session *avant* l'enregistrement du nouveau
/// mot de passe ; renvoyer vers l'accueil à cet instant couperait le parcours.
library;

/// Écrans réservés aux visiteurs non connectés.
const guestOnlyLocations = {
  '/sign-in',
  '/sign-up',
  '/verify-email',
  '/forgot-password',
};

/// Écrans accessibles connecté ou non.
const openLocations = {'/reset-password'};

String? authRedirect({required bool isSignedIn, required String location}) {
  final isGuestOnly = guestOnlyLocations.contains(location);
  if (!isSignedIn && !isGuestOnly && !openLocations.contains(location)) {
    return '/sign-in';
  }
  if (isSignedIn && isGuestOnly) return '/';
  return null;
}
