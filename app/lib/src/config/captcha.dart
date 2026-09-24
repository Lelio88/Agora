/// Réglage du « je ne suis pas un robot » (Cloudflare Turnstile).
///
/// La clé de site vient du build (`--dart-define=AGORA_TURNSTILE_SITE_KEY`),
/// comme l'adresse web : un build de développement n'en a pas, et l'app
/// n'affiche alors rien — la pile locale ne réclame pas de jeton non plus.
///
/// Choix non évident : la page qui porte le widget est servie par le domaine
/// d'Agora (`/captcha.html`), le seul que la clé autorise. L'app ne fabrique
/// donc jamais le widget elle-même ; elle affiche cette page et attend le
/// jeton. Web et Android partagent ainsi exactement le même code.
///
/// Invariant : sans clé **ou** sans adresse web, [captchaConfigProvider] rend
/// `null`, et tous les écrans se comportent comme avant.
library;

import 'package:agora/src/config/web_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class CaptchaConfig {
  const CaptchaConfig({required this.siteKey, required this.pageUrl});

  final String siteKey;

  /// Racine de la page du widget, sans ses paramètres d'affichage.
  final Uri pageUrl;

  /// Adresse complète, pour un thème et une langue donnés. L'origine attendue
  /// est passée à la page : elle ne rendra le jeton qu'à celle-là.
  Uri urlFor({required bool dark, required String language}) => pageUrl.replace(
    queryParameters: {
      'sitekey': siteKey,
      'theme': dark ? 'dark' : 'light',
      'lang': language == 'en' ? 'en' : 'fr',
      'origin': pageUrl.replace(path: '', query: '').toString(),
    },
  );
}

final captchaConfigProvider = Provider<CaptchaConfig?>((ref) {
  const siteKey = String.fromEnvironment('AGORA_TURNSTILE_SITE_KEY');
  final base = ref.watch(webBaseUrlProvider);
  if (siteKey.isEmpty || base == null) return null;
  return CaptchaConfig(
    siteKey: siteKey,
    pageUrl: base.resolve('/captcha.html'),
  );
});

/// Fabrique du widget, isolée derrière un provider : un test fournit sa
/// propre case à cocher, sans navigateur ni vue web.
typedef CaptchaFieldBuilder = Widget Function(
  CaptchaConfig config,
  ValueChanged<String?> onToken,
);
