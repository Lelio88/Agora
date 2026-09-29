/// Adresse de retour d'un parcours OAuth (connexion Google ou Discord,
/// liaison d'un compte Discord), commune aux dépôts qui en lancent un.
///
/// Choix non évidents :
/// - Android revient par `app.agora://login-callback`, déclaré dans
///   AndroidManifest.xml et lu par supabase_flutter (flux PKCE) ;
/// - le web revient sur sa propre page, sans le fragment de routage : le
///   `?code=` s'y ajoute et supabase_flutter l'échange au démarrage.
///
/// Invariant : les deux adresses figurent dans `ADDITIONAL_REDIRECT_URLS`
/// du serveur (et `additional_redirect_urls` en local), sinon GoTrue
/// renvoie vers le site par défaut.
library;

import 'package:flutter/foundation.dart';

/// Retour d'OAuth sur Android.
const androidAuthCallback = 'app.agora://login-callback';

/// Adresse de retour pour la plateforme courante.
String oauthRedirect() =>
    kIsWeb ? Uri.base.removeFragment().toString() : androidAuthCallback;
