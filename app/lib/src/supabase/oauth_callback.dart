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
///   écartés. GoTrue admet tout chemin de l'hôte du Site URL.
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
  'code',
  'state',
  'error',
  'error_code',
  'error_description',
};

/// Adresse de retour pour la plateforme courante.
String oauthRedirect() {
  if (!kIsWeb) return androidAuthCallback;
  final page = pageLocation();
  return page == null
      ? Uri.base.removeFragment().toString()
      : webReturnAddress(page).toString();
}

/// La page [page], sans fragment ni reste d'un retour OAuth.
Uri webReturnAddress(Uri page) {
  final query = Map.of(page.queryParameters)
    ..removeWhere((key, _) => _oauthLeftovers.contains(key));
  return Uri(
    scheme: page.scheme,
    host: page.host,
    port: page.hasPort ? page.port : null,
    path: page.path.isEmpty ? '/' : page.path,
    queryParameters: query.isEmpty ? null : query,
  );
}
