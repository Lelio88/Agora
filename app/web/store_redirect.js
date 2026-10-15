// Renvoie vers le Play Store un lien de partage ouvert dans un navigateur
// Android : si l'app était installée, l'App Link vérifié (assetlinks.json)
// l'aurait déjà ouverte, on n'arrive donc ici que sans elle (ou depuis un
// navigateur intégré qui ignore les App Links, où la fiche Play propose alors
// « Ouvrir »).
//
// Choix non évidents :
//   - chargé AVANT flutter_bootstrap.js, en script classique et synchrone :
//     la redirection part avant que Flutter télécharge quoi que ce soit ;
//   - fichier à part et non script en ligne : la CSP (agora.caddy) n'autorise
//     que 'self' ;
//   - `location.replace` : la page de départ ne reste pas dans l'historique,
//     le bouton retour ne ramène pas sur une redirection ;
//   - la logique est une fonction pure (`playStoreRedirect`), testée par
//     tools/web/store_redirect.test.mjs ; hors navigateur, le fichier
//     l'exporte pour Node et ne touche pas à `location`.
//
// Invariants :
//   - les fragments suivis sont ceux de `appLinkRoute`
//     (app/lib/src/routing/auth_redirect.dart), avec le même alphabet de
//     codes : une route de partage ajoutée là l'est ici ;
//   - seuls Android et la racine du site sont concernés : iOS et ordinateur
//     n'ont pas d'app, la version web est leur voie ;
//   - `?web` est la porte de sortie vers la version web (essais, mainteneurs).
//
// Usage : <script src="store_redirect.js"></script> dans index.html, avant
// flutter_bootstrap.js.

(function (racine) {
  'use strict';

  var PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=app.agora';

  // Alphabet des codes : sans 0, 1, I, O (voir inviteCodeInLocation). Les
  // liens de jumelage et de rdv portent leurs paramètres dans la requête, que
  // leur écran valide.
  var CODE = '[A-HJ-NP-Za-hj-np-z2-9]{8}';
  var LIEN_DE_PARTAGE = new RegExp(
    '^#/(?:(?:join|profile)/' + CODE + '|(?:twin|event)(?:\\?.*)?)$'
  );

  // L'adresse du Play Store si ce chargement doit y aller, sinon `null`.
  function playStoreRedirect(userAgent, pathname, search, hash) {
    if (!/Android/i.test(userAgent)) return null;
    if (pathname !== '/' && pathname !== '') return null;
    if (new URLSearchParams(search).has('web')) return null;
    return LIEN_DE_PARTAGE.test(hash) ? PLAY_STORE_URL : null;
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { playStoreRedirect: playStoreRedirect, PLAY_STORE_URL: PLAY_STORE_URL };
  }

  if (racine && racine.location && racine.navigator) {
    var cible = playStoreRedirect(
      racine.navigator.userAgent,
      racine.location.pathname,
      racine.location.search,
      racine.location.hash
    );
    if (cible) racine.location.replace(cible);
  }
})(typeof window !== 'undefined' ? window : null);
