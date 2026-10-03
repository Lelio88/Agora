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
