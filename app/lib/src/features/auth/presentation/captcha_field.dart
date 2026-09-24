/// Case « je ne suis pas un robot », posée sous les formulaires qui
/// déclenchent un e-mail (inscription, connexion, mot de passe oublié).
///
/// Elle n'affiche pas le widget elle-même : elle montre la page
/// `/captcha.html` servie par le domaine d'Agora — une iframe sur le web, une
/// vue web sur Android — et attend le jeton que cette page lui rend. Un seul
/// code de widget pour les deux plateformes, à l'adresse que la clé de site
/// autorise.
///
/// Le jeton vaut une fois et cinq minutes : chaque envoi refusé doit en
/// redemander un. [onToken] reçoit `null` quand il n'y en a pas (ou plus).
///
/// La fabrique passe par un provider pour que les tests fournissent leur
/// propre case, sans navigateur ni vue web.
library;

import 'package:agora/src/config/captcha.dart';
import 'package:agora/src/features/auth/presentation/captcha_field_stub.dart'
    if (dart.library.io) 'package:agora/src/features/auth/presentation/captcha_field_mobile.dart'
    if (dart.library.js_interop) 'package:agora/src/features/auth/presentation/captcha_field_web.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hauteur du widget de Cloudflare (65 px) plus une marge de sécurité : une
/// iframe trop courte le tronque, et l'utilisateur ne voit plus la case.
const captchaHeight = 74.0;

final captchaFieldBuilderProvider = Provider<CaptchaFieldBuilder>(
  (ref) =>
      (config, onToken) =>
          PlatformCaptchaField(config: config, onToken: onToken),
);

class CaptchaField extends ConsumerWidget {
  const CaptchaField({super.key, required this.config, required this.onToken});

  final CaptchaConfig config;
  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(captchaFieldBuilderProvider)(config, onToken);
}
