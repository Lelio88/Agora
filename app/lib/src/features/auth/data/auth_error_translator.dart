/// Traduit une erreur de GoTrue (ou du réseau) en [AppException].
///
/// Choix non évident : la traduction se fait d'abord sur `AuthException.code`,
/// le code stable de GoTrue (relevés sur le serveur local : `weak_password`,
/// `otp_expired`, `email_not_confirmed`, `invalid_credentials`, `captcha_failed`,
/// `user_already_exists`). Le texte ne sert que de repli pour les pannes
/// réseau, que le SDK emballe parfois dans une `AuthException` sans code.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _byCode = <String, AppException>{
  'invalid_credentials': InvalidCredentialsException(),
  'email_not_confirmed': EmailNotConfirmedException(),
  'user_already_exists': EmailAlreadyRegisteredException(),
  'email_exists': EmailAlreadyRegisteredException(),
  'otp_expired': InvalidCodeException(),
  'weak_password': WeakPasswordException(),
  'email_address_invalid': InvalidEmailException(),
  // GoTrue répond `validation_failed` à une adresse mal formée.
  'validation_failed': InvalidEmailException(),
  'captcha_failed': CaptchaFailedException(),
  'over_email_send_rate_limit': RateLimitedException(),
  'over_request_rate_limit': RateLimitedException(),
};

AppException translateAuthError(Exception error) {
  if (error is AuthRetryableFetchException) return const NetworkException();
  if (error is AuthException) {
    final known = _byCode[error.code];
    if (known != null) return known;
    return looksLikeNetworkError(error.message)
        ? const NetworkException()
        : const UnknownException();
  }
  return looksLikeNetworkError(error.toString())
      ? const NetworkException()
      : const UnknownException();
}
