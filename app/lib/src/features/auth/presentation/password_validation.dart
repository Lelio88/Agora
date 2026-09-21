/// Messages de saisie partagés par les formulaires de compte.
library;

import 'package:agora/src/features/auth/domain/credential_rules.dart';
import 'package:agora/src/localization/app_localizations.dart';

/// Texte d'erreur d'un nouveau mot de passe, ou `null` s'il est conforme.
String? passwordError(String? value, AppLocalizations l10n) =>
    switch (checkPassword(value ?? '')) {
      PasswordIssue.tooShort => l10n.validationPasswordTooShort,
      PasswordIssue.needsLettersAndDigits =>
        l10n.validationPasswordLettersDigits,
      null => null,
    };

/// Texte d'erreur d'un code à 6 chiffres, ou `null` s'il est bien formé.
String? codeError(String? value, AppLocalizations l10n) =>
    isValidCode(value ?? '') ? null : l10n.validationCode;
