/// Adresse de retour d'un parcours OAuth (connexion Google ou Discord,
/// liaison d'un compte Discord), commune aux dépôts qui en lancent un.
///
/// Choix non évidents :
/// - Android revient par `app.agora://login-callback`, déclaré dans
///   AndroidManifest.xml et lu par supabase_flutter (flux PKCE) ;
/// - le web revient sur sa propre page, sans le fragment de routage : le
///   `?code=` s'y ajoute et supabase_flutter l'échange au démarrage. Le
///   chemin et la requête de la page restent (lus dans `window.location` :
///   `Uri.base` est ramené à la racine par `<base href>`) : une connexion
///   faite depuis l'écran de consentement d'un assistant IA
///   (`/oauth/consent?authorization_id=…`) y revient donc, avec sa demande.
///   Les paramètres d'un retour OAuth précédent (`code`, `error`…) sont
///   écartés. GoTrue admet tout chemin de l'hôte du Site URL ;
/// - le retour recharge la page web, et l'app perd ce qu'elle retenait en
///   mémoire : un lien ouvert déconnecté (invitation, jumelage, rdv, lien de
///   profil) voyage donc dans la requête de l'adresse de retour
///   (`?resume=/join/CODE`). `main.dart` le relit ([resumeIn]), le retire de
///   la barre d'adresse ([withoutResume], sinon chaque rechargement y
///   ramènerait) et ne le suit qu'après l'avoir validé (`linkRoute`).
///
/// Invariant : les deux adresses figurent dans `ADDITIONAL_REDIRECT_URLS`
/// du serveur (et `additional_redirect_urls` en local), sinon GoTrue
/// renvoie vers le site par défaut.
library;

import 'package:agora/src/device/page_location.dart';
import 'package:flutter/foundation.dart';

/// Retour d'OAuth sur Android.
const androidAuthCallback = 'app.agora://login-callback';

/// Paramètres laissés par un retour OAuth : jamais renvoyés au suivant.
const _oauthLeftovers = {
  resumeParameter,
  'code',
  'state',
  'error',
  'error_code',
  'error_description',
};

/// Paramètre de l'adresse de retour web qui porte le lien en attente.
const resumeParameter = 'resume';

/// Adresse de retour pour la plateforme courante ; sur le web, [resume] (un
/// emplacement de l'app) y voyage jusqu'au rechargement.
String oauthRedirect({String? resume}) {
  if (!kIsWeb) return androidAuthCallback;
  final page = pageLocation() ?? Uri.base;
  return webReturnAddress(page, resume: resume).toString();
}

/// La page [page], sans fragment ni reste d'un retour OAuth, avec [resume].
Uri webReturnAddress(Uri page, {String? resume}) {
  final query = Map.of(page.queryParameters)
    ..removeWhere((key, _) => _oauthLeftovers.contains(key));
  if (resume != null) query[resumeParameter] = resume;
  return Uri(
    scheme: page.scheme,
    host: page.host,
    port: page.hasPort ? page.port : null,
    path: page.path.isEmpty ? '/' : page.path,
    queryParameters: query.isEmpty ? null : query,
  );
}

/// Le lien en attente porté par l'adresse [page], non encore validé.
String? resumeIn(Uri page) => page.queryParameters[resumeParameter];

/// [page] sans son lien en attente, ou `null` s'il n'y en a pas.
Uri? withoutResume(Uri page) {
  if (!page.queryParameters.containsKey(resumeParameter)) return null;
  final query = Map.of(page.queryParametersAll)..remove(resumeParameter);
  // `Uri.replace` garderait l'ancienne requête si on lui passait `null`.
  return Uri(
    scheme: page.scheme,
    host: page.host,
    port: page.hasPort ? page.port : null,
    path: page.path,
    queryParameters: query.isEmpty ? null : query,
    fragment: page.hasFragment ? page.fragment : null,
  );
}
