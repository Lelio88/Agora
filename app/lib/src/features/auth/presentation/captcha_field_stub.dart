/// Repli pour une plateforme qui n'a ni vue web ni navigateur (aucune, en
/// pratique) : ne rien afficher plutôt que d'empêcher l'écran de se monter.
///
/// Sans jeton, les écrans laissent leur bouton d'envoi désactivé : cette
/// plateforme ne pourrait de toute façon pas s'inscrire tant que le serveur
/// réclame un jeton.
library;

import 'package:agora/src/config/captcha.dart';
import 'package:flutter/widgets.dart';

class PlatformCaptchaField extends StatelessWidget {
  const PlatformCaptchaField({
    super.key,
    required this.config,
    required this.onToken,
  });

  final CaptchaConfig config;
  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
