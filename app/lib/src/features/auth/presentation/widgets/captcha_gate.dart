/// Portillon « je ne suis pas un robot » des écrans de compte.
///
/// Trois écrans déclenchent un envoi d'e-mail (inscription, connexion —
/// renvoi du code — et mot de passe oublié) : ils partagent ici l'état du
/// jeton, la case, et le réarmement.
///
/// Choix non évidents :
///   - sans clé de site dans le build, [captchaSolved] est vrai d'emblée :
///     l'app de développement se comporte comme avant, et le serveur local
///     ne réclame rien ;
///   - un jeton ne vaut qu'une fois. Après un envoi refusé, [resetCaptcha]
///     change la clé du widget, ce qui recharge la page et en obtient un
///     nouveau — sans quoi la seconde tentative échouerait toujours.
library;

import 'package:agora/src/config/captcha.dart';
import 'package:agora/src/features/auth/presentation/captcha_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

mixin CaptchaGate<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? _token;
  int _attempt = 0;

  /// Jeton à envoyer au serveur, ou `null` s'il n'y en a pas (ou pas besoin).
  String? get captchaToken => _token;

  /// Faux tant qu'une vérification est exigée et non faite : le bouton
  /// d'envoi reste alors désactivé.
  bool get captchaSolved =>
      ref.read(captchaConfigProvider) == null || _token != null;

  /// La case, ou rien du tout si le build n'a pas de clé de site.
  Widget captchaField() {
    final config = ref.watch(captchaConfigProvider);
    if (config == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: CaptchaField(
        key: ValueKey(_attempt),
        config: config,
        onToken: (token) => setState(() => _token = token),
      ),
    );
  }

  /// À appeler après un envoi refusé : le jeton précédent est consommé.
  void resetCaptcha() {
    if (!mounted || ref.read(captchaConfigProvider) == null) return;
    setState(() {
      _token = null;
      _attempt++;
    });
  }
}
