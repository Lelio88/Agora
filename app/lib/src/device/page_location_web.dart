/// `window.location.href`, lu par `dart:js_interop` (sans dépendance de plus,
/// comme le champ de vérification humaine).
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Uri? pageLocation() {
  final location = globalContext.getProperty<JSObject?>('location'.toJS);
  final href = location?.getProperty<JSString?>('href'.toJS)?.toDart;
  return href == null ? null : Uri.tryParse(href);
}

/// Remplace l'adresse affichée (`history.replaceState`), sans recharger la
/// page ni ajouter d'entrée à l'historique.
void replacePageLocation(Uri location) {
  final history = globalContext.getProperty<JSObject?>('history'.toJS);
  // `callMethod` prend un premier argument `null` pour « aucun argument » :
  // `replaceState()` partirait à vide et lèverait. La liste garde le `null`.
  history?.callMethodVarArgs<JSAny?>('replaceState'.toJS, [
    null,
    ''.toJS,
    location.toString().toJS,
  ]);
}
