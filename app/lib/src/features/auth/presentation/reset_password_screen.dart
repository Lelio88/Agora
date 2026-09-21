/// Saisie du code de réinitialisation et du nouveau mot de passe.
///
/// Vérifier le code ouvre une session avant l'enregistrement du mot de passe.
/// Le routeur laisse donc cet écran ouvert aux deux états
/// (`auth_redirect.dart`), et c'est l'écran qui mène à l'accueil une fois le
/// mot de passe enregistré. Le mot de passe est contrôlé avant l'envoi : un
/// refus du serveur après coup aurait déjà consommé le code.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/presentation/auth_action_controller.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/auth/presentation/password_validation.dart';
import 'package:agora/src/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:agora/src/features/auth/presentation/widgets/code_field.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changed = await ref
        .read(resetPasswordActionProvider.notifier)
        .run(
          (auth) => auth.resetPassword(
            email: widget.email,
            code: _code.text,
            newPassword: _password.text,
          ),
        );
    if (!changed || !mounted) return;
    context.goNamed(AppRoute.home.name);
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = AppLocalizations.of(context).codeResent;
    final sent = await ref
        .read(requestResetActionProvider.notifier)
        .run((auth) => auth.requestPasswordReset(email: widget.email));
    if (sent) messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reset = ref.watch(resetPasswordActionProvider);
    final resend = ref.watch(requestResetActionProvider);
    final error = reset.error ?? resend.error;
    return KeyedSubtree(
      key: AuthKeys.resetPasswordScreen,
      child: AuthScaffold(
        title: l10n.resetPasswordTitle,
        busy: reset.isLoading || resend.isLoading,
        subtitle: l10n.resetPasswordInstructions(widget.email),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                CodeField(key: AuthKeys.code, controller: _code),
                const SizedBox(height: 12),
                TextFormField(
                  key: AuthKeys.newPassword,
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: l10n.newPasswordLabel,
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
          if (error != null) FormErrorText(messageForError(error, l10n)),
          const SizedBox(height: 24),
          SubmitButton(
            key: AuthKeys.submit,
            label: l10n.resetPasswordButton,
            isLoading: reset.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: AuthKeys.resendCode,
            onPressed: resend.isLoading ? null : _resend,
            child: Text(l10n.resendCodeButton),
          ),
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
