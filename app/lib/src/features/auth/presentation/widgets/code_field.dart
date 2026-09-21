/// Champ du code à 6 chiffres reçu par e-mail : clavier numérique, saisie
/// limitée aux chiffres, remplissage automatique du code quand le système
/// le propose.
library;

import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:agora/src/features/auth/presentation/password_validation.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeField extends StatelessWidget {
  const CodeField({required this.controller, this.onSubmitted, super.key});

  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: l10n.codeLabel, counterText: ''),
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: codeLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(letterSpacing: 8),
      onFieldSubmitted: (_) => onSubmitted?.call(),
      validator: (value) => codeError(value, l10n),
    );
  }
}
