/// Fournisseurs de connexion proposés sur les écrans de compte (Google,
/// Discord), d'après le build : `AGORA_SIGN_IN_PROVIDERS=google,discord`.
///
/// Choix non évident : la liste vient du build et non d'une lecture des
/// réglages du serveur au démarrage. Un bouton vers un fournisseur que
/// GoTrue n'a pas activé mènerait à une page d'erreur ; le build de prod
/// et le `.env` du serveur se règlent donc ensemble (voir
/// docs/auth-architecture.md). Sans la variable : e-mail seulement.
library;

import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Les fournisseurs reconnus dans [raw], dans leur ordre, sans doublon.
List<SocialProvider> parseSignInProviders(String raw) => [
  ...{for (final code in raw.split(',')) ?SocialProvider.fromCode(code)},
];

final signInProvidersProvider = Provider<List<SocialProvider>>(
  (ref) => parseSignInProviders(
    const String.fromEnvironment('AGORA_SIGN_IN_PROVIDERS'),
  ),
);
