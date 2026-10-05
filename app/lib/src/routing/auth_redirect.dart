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
///   un écran de compte seulement, jamais depuis un autre écran ;
/// - une demande d'accès d'un assistant IA ([pendingConsent]) ramène de même
///   à l'écran de consentement, et passe avant une invitation : l'assistant
///   attend, et sa demande expire en dix minutes ;
/// - un lien de jumelage ouvert déconnecté ([pendingTwin]) ramène à son écran,
///   après une demande d'assistant et une invitation.
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
  String? pendingConsent,
  String? pendingTwin,
}) {
  final isGuestOnly = guestOnlyLocations.contains(location);
  if (!isSignedIn && !isGuestOnly && !openLocations.contains(location)) {
    return '/sign-in';
  }
  if (isSignedIn &&
      pendingConsent != null &&
      (isGuestOnly || location == '/')) {
    return Uri(
      path: '/oauth/consent',
      queryParameters: {'authorization_id': pendingConsent},
    ).toString();
  }
  if (isSignedIn && pendingInvite != null && (isGuestOnly || location == '/')) {
    return '/join/$pendingInvite';
  }
  if (isSignedIn && pendingTwin != null && (isGuestOnly || location == '/')) {
    return pendingTwin;
  }
  if (isSignedIn && isGuestOnly) return '/';
  return null;
}

final _joinPath = RegExp(r'^/join/([A-HJ-NP-Za-hj-np-z2-9]{8})$');

/// Code d'invitation d'un emplacement `/join/CODE`, en majuscules ; `null`
/// si l'emplacement n'en est pas un ou si le code n'est pas plausible.
String? inviteCodeInLocation(String location) =>
    _joinPath.firstMatch(location)?.group(1)?.toUpperCase();

/// Emplacement de l'écran de jumelage (paramètres dans la requête).
const twinPath = '/twin';

/// Route d'un lien ouvert dans l'app Android (App Link), ou `null`.
///
/// Le web route « par dièse » : une invitation est
/// `https://agora.heianenterprise.com/#/join/CODE`, un lien de jumelage
/// `…/#/twin?de=…`. Android ne filtre pas sur le fragment, l'App Link vise
/// donc la racine, et le routeur reçoit `/` avec le fragment : c'est ce
/// fragment qu'il faut suivre. Seuls une invitation et un lien de jumelage
/// sont suivis : un autre fragment reste sans effet. Les paramètres d'un
/// jumelage ne sont pas jugés ici : son écran les valide.
String? appLinkRoute(Uri uri) {
  if (uri.path != '/' && uri.path.isNotEmpty) return null;
  final code = inviteCodeInLocation(uri.fragment);
  if (code != null) return '/join/$code';
  final inner = Uri.tryParse(uri.fragment);
  if (inner == null || inner.path != twinPath) return null;
  return Uri(
    path: twinPath,
    query: inner.query.isEmpty ? null : inner.query,
  ).toString();
}
