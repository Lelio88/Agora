/// Clés des écrans de compte, pour que les tests visent un champ sans
/// dépendre de son libellé traduit.
library;

import 'package:flutter/widgets.dart';

abstract final class AuthKeys {
  static const signInScreen = ValueKey('auth.signInScreen');
  static const signUpScreen = ValueKey('auth.signUpScreen');
  static const verifyEmailScreen = ValueKey('auth.verifyEmailScreen');
  static const forgotPasswordScreen = ValueKey('auth.forgotPasswordScreen');
  static const resetPasswordScreen = ValueKey('auth.resetPasswordScreen');

  static const email = ValueKey('auth.email');
  static const password = ValueKey('auth.password');
  static const displayName = ValueKey('auth.displayName');
  static const code = ValueKey('auth.code');
  static const newPassword = ValueKey('auth.newPassword');

  static const submit = ValueKey('auth.submit');
  static const resendCode = ValueKey('auth.resendCode');
  static const confirmEmailAction = ValueKey('auth.confirmEmailAction');
  static const signUpLink = ValueKey('auth.signUpLink');
  static const signInLink = ValueKey('auth.signInLink');
  static const forgotPasswordLink = ValueKey('auth.forgotPasswordLink');
}
