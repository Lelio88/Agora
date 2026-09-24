/// Version web : la page du widget dans une iframe, et le jeton reçu par
/// message.
///
/// Choix non évidents :
///   - `HtmlElementView.fromTagName` fabrique l'iframe sans enregistrer de
///     fabrique de vue, donc sans identifiant global à gérer ;
///   - l'app n'accepte un message que de l'origine qui sert la page : un
///     autre cadre de la page ne peut pas lui glisser un jeton ;
///   - interopérabilité par `dart:js_interop` (SDK) plutôt qu'un paquet de
///     plus : trois appels suffisent.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:agora/src/config/captcha.dart';
import 'package:agora/src/features/auth/presentation/captcha_field.dart';
import 'package:flutter/material.dart';

@JS('window')
external JSObject get _window;

class PlatformCaptchaField extends StatefulWidget {
  const PlatformCaptchaField({
    super.key,
    required this.config,
    required this.onToken,
  });

  final CaptchaConfig config;
  final ValueChanged<String?> onToken;

  @override
  State<PlatformCaptchaField> createState() => _PlatformCaptchaFieldState();
}

class _PlatformCaptchaFieldState extends State<PlatformCaptchaField> {
  JSFunction? _listener;

  @override
  void initState() {
    super.initState();
    final listener = ((JSObject event) => _onMessage(event)).toJS;
    _listener = listener;
    _window.callMethod('addEventListener'.toJS, 'message'.toJS, listener);
  }

  void _onMessage(JSObject event) {
    final origin = (event.getProperty('origin'.toJS) as JSString?)?.toDart;
    final expected = widget.config.pageUrl
        .replace(path: '', query: '')
        .toString();
    // Uri rend « https://hôte » sans barre finale ; l'origine d'un message en
    // porte une… ou pas, selon le navigateur.
    if (origin == null || !expected.startsWith(origin)) return;
    final data = event.getProperty('data'.toJS);
    if (data == null || !data.isA<JSObject>()) return;
    final token = ((data as JSObject).getProperty(
      'agoraTurnstile'.toJS,
    ) as JSString?)?.toDart;
    if (token == null) return;
    widget.onToken(token.isEmpty ? null : token);
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) {
      _window.callMethod('removeEventListener'.toJS, 'message'.toJS, listener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = widget.config.urlFor(
      dark: dark,
      language: Localizations.localeOf(context).languageCode,
    );
    return SizedBox(
      height: captchaHeight,
      child: HtmlElementView.fromTagName(
        tagName: 'iframe',
        onElementCreated: (element) {
          (element as JSObject)
            ..callMethod('setAttribute'.toJS, 'src'.toJS, url.toString().toJS)
            ..callMethod('setAttribute'.toJS, 'title'.toJS, 'Turnstile'.toJS)
            ..callMethod(
              'setAttribute'.toJS,
              'style'.toJS,
              'border:0;width:100%;height:${captchaHeight}px;background:transparent'
                  .toJS,
            );
        },
      ),
    );
  }
}
