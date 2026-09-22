import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _all = <AppException>[
  InvalidCredentialsException(),
  EmailNotConfirmedException(),
  EmailAlreadyRegisteredException(),
  InvalidCodeException(),
  WeakPasswordException(),
  InvalidEmailException(),
  RateLimitedException(),
  InvalidTimezoneException(),
  EventNotFoundException(),
  InvalidRangeException(),
  CalendarNotFoundException(),
  LastNativeCalendarException(),
  InvalidInviteException(),
  NotGroupMemberException(),
  NotGroupOwnerException(),
  InvalidMemberException(),
  NetworkException(),
  UnknownException(),
];

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test(
      'every AppException has a message in ${locale.languageCode}',
      () async {
        final l10n = await AppLocalizations.delegate.load(locale);

        for (final error in _all) {
          expect(messageFor(error, l10n), isNotEmpty, reason: error.code);
        }
      },
    );
  }

  test('an untranslated error shows the generic message', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('fr'));

    expect(messageForError(StateError('raw'), l10n), l10n.errorUnknown);
  });
}
