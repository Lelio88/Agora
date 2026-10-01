/// Saisie du code de confirmation reçu après l'inscription.
///
/// Un code juste ouvre la session, et le routeur quitte l'écran de lui-même.
/// « Renvoyer le code » en redemande un, que GoTrue limite en fréquence.
///
/// L'inscription répond pareil qu'une adresse ait déjà un compte ou non : pour
/// une adresse inscrite, aucun code ne part. L'écran le dit donc à tout le
/// monde, sans affirmer qu'un code est parti, et mène à la connexion comme à
/// « Mot de passe oublié » : le titulaire n'attend pas en vain, et personne
/// n'apprend si l'adresse est inscrite.
library;

import 'package:agora/src/common_widgets/form_error_text.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/auth/presentation/auth_action_controller.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/auth/presentation/widgets/captcha_gate.dart';
import 'package:agora/src/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:agora/src/features/auth/presentation/widgets/code_field.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with CaptchaGate {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(verifyCodeActionProvider.notifier)
        .run(
          (auth) =>
              auth.verifySignUpCode(email: widget.email, code: _code.text),
        );
  }

  Future<void> _resend() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmation = AppLocalizations.of(context).codeResent;
    final sent = await ref
        .read(resendCodeActionProvider.notifier)
        .run(
          (auth) => auth.resendSignUpCode(
            email: widget.email,
            captchaToken: captchaToken,
          ),
        );
    resetCaptcha();
    if (sent) messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final verify = ref.watch(verifyCodeActionProvider);
    final resend = ref.watch(resendCodeActionProvider);
    final error = verify.error ?? resend.error;
    return KeyedSubtree(
      key: AuthKeys.verifyEmailScreen,
      child: AuthScaffold(
        title: l10n.verifyEmailTitle,
        busy: verify.isLoading || resend.isLoading,
        subtitle: l10n.verifyEmailInstructions(widget.email),
        children: [
          Form(
            key: _formKey,
            child: CodeField(
              key: AuthKeys.code,
              controller: _code,
              onSubmitted: _submit,
            ),
          ),
          captchaField(),
          if (error != null) FormErrorText(messageForError(error, l10n)),
          const SizedBox(height: 16),
          SubmitButton(
            key: AuthKeys.submit,
            label: l10n.verifyButton,
            isLoading: verify.isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: AuthKeys.resendCode,
            onPressed: resend.isLoading || !captchaSolved ? null : _resend,
            child: Text(l10n.resendCodeButton),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.verifyEmailExistingAccountHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(
            key: AuthKeys.signInLink,
            onPressed: () => context.goNamed(AppRoute.signIn.name),
            child: Text(l10n.signInLink),
          ),
          TextButton(
            key: AuthKeys.forgotPasswordLink,
            onPressed: () => context.goNamed(AppRoute.forgotPassword.name),
            child: Text(l10n.forgotPasswordLink),
          ),
        ],
      ),
    );
  }
}
