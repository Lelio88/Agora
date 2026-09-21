// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Agora';

  @override
  String get homeTagline => 'Your calendars, together.';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get profileTooltip => 'Profile';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHelper =>
      'At least 8 characters, with letters and numbers.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameHelper => 'Shown to the members of your groups.';

  @override
  String get codeLabel => '6-digit code';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInButton => 'Sign in';

  @override
  String get forgotPasswordLink => 'Forgot your password?';

  @override
  String get noAccountPrompt => 'No account yet?';

  @override
  String get createAccountLink => 'Create an account';

  @override
  String get confirmEmailAction => 'Get a confirmation code';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get signUpButton => 'Create my account';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String get verifyEmailTitle => 'Check your inbox';

  @override
  String verifyEmailInstructions(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get verifyButton => 'Confirm';

  @override
  String get resendCodeButton => 'Resend the code';

  @override
  String get codeResent => 'New code sent.';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordInstructions =>
      'Enter your email: if an account uses it, you will receive a code to choose a new password.';

  @override
  String get sendCodeButton => 'Send me a code';

  @override
  String get resetPasswordTitle => 'New password';

  @override
  String resetPasswordInstructions(String email) {
    return 'Enter the code sent to $email and choose a new password.';
  }

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetPasswordButton => 'Change password';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLanguageLabel => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get profileTimezoneLabel => 'Time zone';

  @override
  String get useDeviceTimezone => 'Use this device\'s';

  @override
  String get saveButton => 'Save';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get validationEmail => 'Invalid email address.';

  @override
  String get validationPasswordTooShort => 'At least 8 characters.';

  @override
  String get validationPasswordLettersDigits => 'Use both letters and numbers.';

  @override
  String get validationCode => 'The code has 6 digits.';

  @override
  String get validationDisplayName => 'Between 1 and 60 characters.';

  @override
  String get errorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get errorEmailNotConfirmed =>
      'Confirm your email first with the code we sent you.';

  @override
  String get errorEmailAlreadyRegistered =>
      'An account already uses this email. Sign in, or use “Forgot your password?”.';

  @override
  String get errorInvalidCode => 'Incorrect or expired code.';

  @override
  String get errorWeakPassword =>
      'Password too weak: at least 8 characters, with letters and numbers.';

  @override
  String get errorInvalidEmail => 'Invalid email address.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get errorInvalidTimezone => 'Unknown time zone.';

  @override
  String get errorNetwork => 'Can\'t reach the server. Check your connection.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';
}
