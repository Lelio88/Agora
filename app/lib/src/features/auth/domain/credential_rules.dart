/// Règles de saisie des formulaires de compte, alignées sur la configuration
/// GoTrue (`supabase/config.toml`) : les vérifier avant l'envoi évite un
/// aller-retour, et surtout un code de réinitialisation consommé pour un mot
/// de passe que le serveur refuserait ensuite.
///
/// Invariant : [minPasswordLength] et la règle lettres + chiffres suivent
/// `minimum_password_length` et `password_requirements` du serveur.
library;

const minPasswordLength = 8;
const maxDisplayNameLength = 60;
const codeLength = 6;

enum PasswordIssue { tooShort, needsLettersAndDigits }

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _letter = RegExp('[A-Za-z]');
final _digit = RegExp('[0-9]');
final _code = RegExp('^[0-9]{$codeLength}\$');

bool isValidEmail(String input) => _email.hasMatch(input.trim());

PasswordIssue? checkPassword(String input) {
  if (input.length < minPasswordLength) return PasswordIssue.tooShort;
  if (!_letter.hasMatch(input) || !_digit.hasMatch(input)) {
    return PasswordIssue.needsLettersAndDigits;
  }
  return null;
}

bool isValidCode(String input) => _code.hasMatch(input.trim());

bool isValidDisplayName(String input) {
  final trimmed = input.trim();
  return trimmed.isNotEmpty && trimmed.length <= maxDisplayNameLength;
}
