/// Règle de redirection selon la session, isolée du routeur pour être testée
/// seule.
///
/// Invariants :
/// - `/reset-password` reste ouvert aux deux états. Vérifier le code de
///   réinitialisation ouvre une session *avant* l'enregistrement du nouveau
///   mot de passe ; renvoyer vers l'accueil à cet instant couperait le
///   parcours ;
/// - une invitation ouverte déconnecté ([pendingInvite], retenue par le
///   routeur) ramène à `/join/CODE` dès la connexion — depuis l'accueil ou
///   un écran de compte seulement, jamais depuis un autre écran.
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

String? authRedirect({
  required bool isSignedIn,
  required String location,
  String? pendingInvite,
}) {
  final isGuestOnly = guestOnlyLocations.contains(location);
  if (!isSignedIn && !isGuestOnly && !openLocations.contains(location)) {
    return '/sign-in';
  }
  if (isSignedIn && pendingInvite != null && (isGuestOnly || location == '/')) {
    return '/join/$pendingInvite';
  }
  if (isSignedIn && isGuestOnly) return '/';
  return null;
}

final _joinPath = RegExp(r'^/join/([A-HJ-NP-Za-hj-np-z2-9]{8})$');

/// Code d'invitation d'un emplacement `/join/CODE`, en majuscules ; `null`
/// si l'emplacement n'en est pas un ou si le code n'est pas plausible.
String? inviteCodeInLocation(String location) =>
    _joinPath.firstMatch(location)?.group(1)?.toUpperCase();
