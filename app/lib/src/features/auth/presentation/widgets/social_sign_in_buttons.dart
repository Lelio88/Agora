/// « Continuer avec Google / Discord », sous le formulaire de connexion et
/// celui d'inscription : le même geste crée le compte ou y reconnecte.
///
/// Choix non évidents :
/// - pas de vérification humaine ici : le parcours passe par la page du
///   fournisseur, qui fait la sienne, et ne déclenche aucun e-mail d'Agora
///   (la ressource que le CAPTCHA protège) ;
/// - un appui ouvre le navigateur et rend la main aussitôt : la session
///   arrive au retour, et le routeur quitte l'écran de lui-même ;
/// - rien ne s'affiche si le build ne propose aucun fournisseur.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/config/sign_in_providers.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:agora/src/features/auth/presentation/auth_action_controller.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({super.key});

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  /// La page n'a pas pu s'ouvrir (aucun navigateur) : pas une exception.
  bool _notOpened = false;

  Future<void> _signIn(SocialProvider provider) async {
    setState(() => _notOpened = false);
    var opened = true;
    await ref
        .read(socialSignInActionProvider.notifier)
        .run((auth) async => opened = await auth.signInWith(provider));
    if (mounted && !opened) setState(() => _notOpened = true);
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(signInProvidersProvider);
    if (providers.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final action = ref.watch(socialSignInActionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l10n.orDivider),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        for (final provider in providers) ...[
          OutlinedButton.icon(
            key: AuthKeys.socialSignIn(provider.code),
            onPressed: action.isLoading ? null : () => _signIn(provider),
            icon: Icon(switch (provider) {
              SocialProvider.google => Icons.g_mobiledata,
              SocialProvider.discord => Icons.forum_outlined,
            }),
            label: Text(switch (provider) {
              SocialProvider.google => l10n.continueWithGoogle,
              SocialProvider.discord => l10n.continueWithDiscord,
            }),
          ),
          const SizedBox(height: 8),
        ],
        if (action.error case final error?)
          FormErrorText(messageForError(error, l10n))
        else if (_notOpened)
          FormErrorText(l10n.socialSignInFailed),
      ],
    );
  }
}
