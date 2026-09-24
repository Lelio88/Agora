import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/data/auth_error_translator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Codes relevés sur le GoTrue local (voir docs/architecture.md §7).
  final byCode = <String, Type>{
    'invalid_credentials': InvalidCredentialsException,
    'email_not_confirmed': EmailNotConfirmedException,
    'user_already_exists': EmailAlreadyRegisteredException,
    'email_exists': EmailAlreadyRegisteredException,
    'otp_expired': InvalidCodeException,
    'weak_password': WeakPasswordException,
    'email_address_invalid': InvalidEmailException,
    'validation_failed': InvalidEmailException,
    // Relevé en production le 2026-09-24, vérification activée : un jeton
    // absent ou périmé donne ce code, et non un message libre.
    'captcha_failed': CaptchaFailedException,
    'over_email_send_rate_limit': RateLimitedException,
    'over_request_rate_limit': RateLimitedException,
  };

  byCode.forEach((code, expected) {
    test('maps GoTrue code "$code" to $expected', () {
      final translated = translateAuthError(
        AuthApiException('msg', code: code),
      );

      expect(translated.runtimeType, expected);
    });
  });

  test('maps a retryable fetch failure to NetworkException', () {
    expect(
      translateAuthError(AuthRetryableFetchException(message: 'boom')),
      isA<NetworkException>(),
    );
  });

  test('maps an AuthException wrapping a socket error to NetworkException', () {
    const wrapped = AuthException(
      'ClientException with SocketException: Connection refused',
    );

    expect(translateAuthError(wrapped), isA<NetworkException>());
  });

  test('maps an unknown GoTrue code to UnknownException', () {
    expect(
      translateAuthError(AuthApiException('msg', code: 'brand_new_code')),
      isA<UnknownException>(),
    );
  });

  test('maps a non-auth exception that is not network to UnknownException', () {
    expect(
      translateAuthError(const FormatException('bad')),
      isA<UnknownException>(),
    );
  });
}
