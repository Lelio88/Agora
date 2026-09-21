/// Connexion par e-mail et mot de passe.
///
/// Une adresse pas encore confirmée fait apparaître « Recevoir un code de
/// confirmation » : un nouveau code part, puis l'écran de saisie s'ouvre.
/// Sans cette sortie, le code d'origine expiré laisserait le compte bloqué.
/// La réussite n'appelle aucune navigation : le routeur redirige de lui-même
/// dès que la session s'ouvre.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:agora/src/features/auth/presentation/auth_action_controller.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(signInActionProvider.notifier)
        .run(
          (auth) => auth.signIn(email: _email.text, password: _password.text),
        );
  }

  Future<void> _requestConfirmationCode() async {
    final email = _email.text.trim();
    final sent = await ref
        .read(resendCodeActionProvider.notifier)
        .run((auth) => auth.resendSignUpCode(email: email));
    if (!sent || !mounted) return;
    context.goNamed(
      AppRoute.verifyEmail.name,
      queryParameters: {'email': email},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signIn = ref.watch(signInActionProvider);
    final resend = ref.watch(resendCodeActionProvider);
    final error = signIn.error ?? resend.error;
    return KeyedSubtree(
      key: AuthKeys.signInScreen,
      child: AuthScaffold(
        title: l10n.signInTitle,
        busy: signIn.isLoading || resend.isLoading,
        subtitle: l10n.homeTagline,
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
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
                  decoration: InputDecoration(labelText: l10n.passwordLabel),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: AuthKeys.forgotPasswordLink,
              onPressed: () => context.goNamed(AppRoute.forgotPassword.name),
              child: Text(l10n.forgotPasswordLink),
            ),
          ),
          if (error != null) FormErrorText(messageForError(error, l10n)),
          if (signIn.error is EmailNotConfirmedException)
            OutlinedButton(
              key: AuthKeys.confirmEmailAction,
              onPressed: resend.isLoading ? null : _requestConfirmationCode,
              child: Text(l10n.confirmEmailAction),
            ),
          const SizedBox(height: 16),
          SubmitButton(
            key: AuthKeys.submit,
            label: l10n.signInButton,
            isLoading: signIn.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 16),
          AuthSwitchPrompt(
            actionKey: AuthKeys.signUpLink,
            prompt: l10n.noAccountPrompt,
            action: l10n.createAccountLink,
            onPressed: () => context.goNamed(AppRoute.signUp.name),
          ),
        ],
      ),
    );
  }
}
