// Logique de captcha.html (voir son commentaire de tête), sortie de la page
// pour que la politique de sécurité (CSP) n'ait à autoriser aucun script en
// ligne. Chargé AVANT l'API Turnstile, qui appelle auTour() une fois prête.

const params = new URLSearchParams(location.search);

function rendre(jeton) {
  // Android : canal posé par la vue web de l'app.
  if (window.Agora && window.Agora.postMessage) {
    window.Agora.postMessage(jeton);
  }
  // Web : la page est dans une iframe ; on ne parle qu'à l'origine annoncée
  // par l'app, jamais à « * ».
  if (window.parent !== window) {
    window.parent.postMessage({ agoraTurnstile: jeton }, params.get('origin') || location.origin);
  }
}

function auTour() {
  turnstile.render('#widget', {
    sitekey: params.get('sitekey'),
    theme: params.get('theme') === 'dark' ? 'dark' : 'light',
    language: params.get('lang') === 'en' ? 'en' : 'fr',
    callback: rendre,
    'error-callback': function () { rendre(''); },
    'expired-callback': function () { rendre(''); },
    'timeout-callback': function () { rendre(''); },
  });
}
