/// Liens vers la version web d'Agora (invitation d'un groupe).
///
/// L'adresse du site vient du build (`--dart-define=AGORA_WEB_URL=…`, ou
/// `config/<env>.json`) : elle n'est connue qu'à la mise en ligne. Sans
/// elle, l'app ne propose que le code, jamais un lien faux. Le routage web
/// est « par dièse » (`/#/join/CODE`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Adresse racine de la version web, ou `null` si le build n'en a pas.
Uri? parseWebBaseUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  return uri.host.isEmpty ? null : uri;
}

final webBaseUrlProvider = Provider<Uri?>(
  (ref) => parseWebBaseUrl(const String.fromEnvironment('AGORA_WEB_URL')),
);

/// Lien d'invitation : la page « Rejoindre » de la version web.
Uri inviteLink(Uri base, String code) => base.replace(
  path: base.path.isEmpty ? '/' : base.path,
  fragment: '/join/${code.toUpperCase()}',
);
