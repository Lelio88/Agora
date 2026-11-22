/// Point d'entrée d'Agora : valide la configuration, initialise Supabase, puis
/// monte l'app sous la composition root.
///
/// Invariant : la configuration est validée avant toute initialisation. Une
/// configuration incomplète fait planter le démarrage de façon visible au
/// lieu de viser le mauvais backend.
///
/// Sur le web, l'adresse réelle de la page (`pageLocation`, pas `Uri.base`,
/// ramené à la racine par `<base href>`) est lue AVANT l'initialisation de
/// Supabase : une demande d'accès d'un assistant IA
/// (`/oauth/consent?authorization_id=…`) y survit au retour d'une connexion
/// Google ou Discord, dont Supabase échange ensuite le code. Un lien ouvert
/// déconnecté (invitation…) y revient de même, par `?resume=` : il est lu,
/// validé, puis retiré de la barre d'adresse, `?code=` laissé à Supabase.
library;

import 'package:agora/src/app.dart';
import 'package:agora/src/composition_root.dart';
import 'package:agora/src/device/page_location.dart';
import 'package:agora/src/exceptions/async_error_logger.dart';
import 'package:agora/src/features/assistant/application/assistant_providers.dart';
import 'package:agora/src/routing/app_router.dart';
import 'package:agora/src/routing/auth_redirect.dart';
import 'package:agora/src/supabase/oauth_callback.dart';
import 'package:agora/src/supabase/supabase_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sur le web, `push` met aussi l'URL à jour : un rafraîchissement sur le
  // profil y reste au lieu de revenir à l'accueil.
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final config = SupabaseConfig.fromEnvironment();
  final page = pageLocation();
  final pendingConsent = page == null ? null : consentRequestIn(page);
  final resumedLink = page == null ? null : linkRoute(resumeIn(page));
  if (page != null) {
    if (withoutResume(page) case final cleaned?) replacePageLocation(cleaned);
  }
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
  );
  runApp(
    ProviderScope(
      observers: [AsyncErrorLogger()],
      overrides: [
        ...prodOverrides(Supabase.instance.client),
        mcpUrlProvider.overrideWithValue(mcpUrlFor(Uri.parse(config.url))),
        pendingConsentProvider.overrideWithValue(
          PendingConsent(pendingConsent),
        ),
        resumedLinkProvider.overrideWithValue(ResumedLink(resumedLink)),
      ],
      child: const AgoraApp(),
    ),
  );
}
