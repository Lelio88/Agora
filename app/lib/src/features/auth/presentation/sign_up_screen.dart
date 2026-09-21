/// Inscription : nom affiché, adresse, mot de passe.
///
/// La langue de l'interface et le fuseau de l'appareil partent avec la
/// demande : le profil naît déjà réglé, et le code de confirmation arrive
/// dans la bonne langue. Le mot de passe est vérifié ici selon la règle du
/// serveur, avant tout envoi.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/device/device_timezone.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:agora/src/features/auth/presentation/auth_action_controller.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/auth/presentation/password_validation.dart';
import 'package:agora/src/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final locale = Localizations.localeOf(context).languageCode;
    final deviceTimezone = ref.read(deviceTimezoneProvider);
    final created = await ref
        .read(signUpActionProvider.notifier)
        .run(
          (auth) async => auth.signUp(
            email: email,
            password: _password.text,
            displayName: _displayName.text,
            locale: locale,
            timezone: await deviceTimezone.current(),
          ),
        );
    if (!created || !mounted) return;
    context.goNamed(
      AppRoute.verifyEmail.name,
      queryParameters: {'email': email},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signUp = ref.watch(signUpActionProvider);
    return KeyedSubtree(
      key: AuthKeys.signUpScreen,
      child: AuthScaffold(
        title: l10n.signUpTitle,
        busy: signUp.isLoading,
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  key: AuthKeys.displayName,
                  controller: _displayName,
                  decoration: InputDecoration(
                    labelText: l10n.displayNameLabel,
                    helperText: l10n.displayNameHelper,
                  ),
                  autofillHints: const [AutofillHints.nickname],
                  textInputAction: TextInputAction.next,
                  validator: (value) => isValidDisplayName(value ?? '')
                      ? null
                      : l10n.validationDisplayName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: AuthKeys.email,
                  controller: _email,
                  decoration: InputDecoration(labelText: l10n.emailLabel),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      isValidEmail(value ?? '') ? null : l10n.validationEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: AuthKeys.password,
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    helperText: l10n.passwordHelper,
                    helperMaxLines: 2,
                  ),
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) => passwordError(value, l10n),
                ),
              ],
            ),
          ),
          if (signUp.error case final error?)
            FormErrorText(messageForError(error, l10n)),
          const SizedBox(height: 24),
          SubmitButton(
            key: AuthKeys.submit,
            label: l10n.signUpButton,
            isLoading: signUp.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          AuthSwitchPrompt(
            actionKey: AuthKeys.signInLink,
            prompt: l10n.haveAccountPrompt,
            action: l10n.signInLink,
            onPressed: () => context.goNamed(AppRoute.signIn.name),
          ),
        ],
      ),
    );
  }
}
