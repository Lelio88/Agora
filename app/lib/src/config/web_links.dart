/// Liens vers la version web d'Agora : invitation d'un groupe, pages légales.
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

/// Pages légales, servies par la version web (`app/web/legal/`, recopié tel
/// quel par `flutter build web`). Leurs adresses sont aussi celles données à
/// la fiche Play Store : elles ne changent pas.
enum LegalPage {
  privacy('/legal/confidentialite.html'),
  notice('/legal/mentions-legales.html'),
  terms('/legal/conditions.html');

  const LegalPage(this.path);

  final String path;
}

/// Lien d'une page légale. Bilingue à l'ouverture : la page choisit la langue
/// du navigateur, il n'y a donc qu'une adresse par sujet.
Uri legalLink(Uri base, LegalPage page) => base.resolve(page.path);
