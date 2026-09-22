/// Texte affiché pour chaque [AppException], dans la langue de l'interface.
///
/// Le `switch` est exhaustif sur la hiérarchie scellée : une nouvelle
/// exception sans message ne compile pas. Les cas que le serveur rend
/// indiscernables partagent un même texte (voir `app_exception.dart`).
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/localization/app_localizations.dart';

String messageFor(AppException error, AppLocalizations l10n) => switch (error) {
  InvalidCredentialsException() => l10n.errorInvalidCredentials,
  EmailNotConfirmedException() => l10n.errorEmailNotConfirmed,
  EmailAlreadyRegisteredException() => l10n.errorEmailAlreadyRegistered,
  InvalidCodeException() => l10n.errorInvalidCode,
  WeakPasswordException() => l10n.errorWeakPassword,
  InvalidEmailException() => l10n.errorInvalidEmail,
  RateLimitedException() => l10n.errorRateLimited,
  InvalidTimezoneException() => l10n.errorInvalidTimezone,
  EventNotFoundException() => l10n.errorEventNotFound,
  InvalidRangeException() => l10n.errorUnknown,
  CalendarNotFoundException() => l10n.errorCalendarNotFound,
  LastNativeCalendarException() => l10n.errorLastCalendar,
  NetworkException() => l10n.errorNetwork,
  UnknownException() => l10n.errorUnknown,
};

/// Variante pour une erreur quelconque : tout ce qui n'est pas une
/// [AppException] (donc un oubli de traduction) s'affiche comme inconnu.
String messageForError(Object error, AppLocalizations l10n) =>
    error is AppException ? messageFor(error, l10n) : l10n.errorUnknown;
