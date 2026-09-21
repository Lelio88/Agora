/// Demande d'un code de réinitialisation du mot de passe.
///
/// Invariant (anti-énumération) : la demande « réussit » toujours et mène à
/// l'écran de saisie, qu'un compte utilise l'adresse ou non. Le texte le dit
/// sans rien confirmer (« si un compte y est associé »).
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final sent = await ref
        .read(requestResetActionProvider.notifier)
        .run((auth) => auth.requestPasswordReset(email: email));
    if (!sent || !mounted) return;
    context.goNamed(
      AppRoute.resetPassword.name,
      queryParameters: {'email': email},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = ref.watch(requestResetActionProvider);
    return KeyedSubtree(
      key: AuthKeys.forgotPasswordScreen,
      child: AuthScaffold(
        title: l10n.forgotPasswordTitle,
        busy: request.isLoading,
        subtitle: l10n.forgotPasswordInstructions,
        children: [
          Form(
            key: _formKey,
            child: TextFormField(
              key: AuthKeys.email,
              controller: _email,
              decoration: InputDecoration(labelText: l10n.emailLabel),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: (_) => _submit(),
              validator: (value) =>
                  isValidEmail(value ?? '') ? null : l10n.validationEmail,
            ),
          ),
          if (request.error case final error?)
            FormErrorText(messageForError(error, l10n)),
          const SizedBox(height: 24),
          SubmitButton(
            key: AuthKeys.submit,
            label: l10n.sendCodeButton,
            isLoading: request.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: AuthKeys.signInLink,
            onPressed: () => context.goNamed(AppRoute.signIn.name),
            child: Text(l10n.signInLink),
          ),
        ],
      ),
    );
  }
}
