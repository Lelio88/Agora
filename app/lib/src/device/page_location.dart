/// L'adresse réelle de la page (web), ou `null` hors du web.
///
/// Choix non évident : sur le web, `Uri.base` vaut `document.baseURI`, que la
/// balise `<base href="/">` de Flutter ramène à la racine du site — chemin et
/// requête y sont perdus. Or l'écran de consentement d'un assistant IA est
/// atteint par un vrai chemin (`/oauth/consent?authorization_id=…`) : seule
/// `window.location` le porte.
library;

export 'page_location_stub.dart'
    if (dart.library.js_interop) 'page_location_web.dart';
