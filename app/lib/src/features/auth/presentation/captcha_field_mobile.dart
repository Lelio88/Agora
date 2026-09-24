/// Version Android : la page du widget dans une vue web, et le jeton reçu par
/// un canal JavaScript.
///
/// Choix non évidents :
///   - Turnstile n'a pas de composant natif : une vue web est le seul moyen
///     d'obtenir un jeton valable pour la clé de site ;
///   - fond transparent et hauteur fixe : la vue doit se fondre dans le
///     formulaire, pas ressembler à une page ouverte dans l'app ;
///   - le canal s'appelle « Agora », comme la page l'attend.
library;

import 'package:agora/src/config/captcha.dart';
import 'package:agora/src/features/auth/presentation/captcha_field.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  WebViewController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le thème et la langue ne sont connus qu'ici, et peuvent changer : la
    // vue est reconstruite plutôt que de servir un widget clair sur un fond
    // sombre.
    final url = widget.config.urlFor(
      dark: Theme.of(context).brightness == Brightness.dark,
      language: Localizations.localeOf(context).languageCode,
    );
    if (_controller != null) return;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'Agora',
        onMessageReceived: (message) =>
            widget.onToken(message.message.isEmpty ? null : message.message),
      )
      ..loadRequest(url);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return SizedBox(
      height: captchaHeight,
      child: controller == null
          ? const SizedBox.shrink()
          : WebViewWidget(controller: controller),
    );
  }
}
