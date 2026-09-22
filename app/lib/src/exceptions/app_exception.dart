/// Hiérarchie scellée des erreurs métier d'Agora.
///
/// Les couches `data/` traduisent les erreurs de transport (Supabase,
/// PostgREST, réseau) en sous-classes de [AppException] ; l'interface ne voit
/// jamais une `AuthException` ou une `PostgrestException` brute. `sealed` rend
/// le `switch` des messages exhaustif (`app_exception_messages.dart`) :
/// ajouter un cas sans son texte ne compile pas.
///
/// Invariant (anti-énumération) : ce que le serveur rend volontairement
/// indiscernable le reste. Compte inexistant et mauvais mot de passe
/// produisent tous deux [InvalidCredentialsException].
library;

sealed class AppException implements Exception {
  const AppException(this.code, this.message);

  /// Identifiant stable, indépendant de la langue.
  final String code;

  /// Message technique pour les logs — l'interface passe par la l10n.
  final String message;

  @override
  String toString() => '$code: $message';
}

// --- Authentification ---------------------------------------------------------

final class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
    : super('invalid-credentials', 'Invalid email or password');
}

final class EmailNotConfirmedException extends AppException {
  const EmailNotConfirmedException()
    : super('email-not-confirmed', 'Email address not confirmed yet');
}

final class EmailAlreadyRegisteredException extends AppException {
  const EmailAlreadyRegisteredException()
    : super('email-already-registered', 'An account already uses this email');
}

final class InvalidCodeException extends AppException {
  const InvalidCodeException()
    : super('invalid-code', 'Verification code expired or invalid');
}

final class WeakPasswordException extends AppException {
  const WeakPasswordException()
    : super('weak-password', 'Password does not meet the policy');
}

final class InvalidEmailException extends AppException {
  const InvalidEmailException()
    : super('invalid-email', 'Email address rejected by the server');
}

final class RateLimitedException extends AppException {
  const RateLimitedException()
    : super('rate-limited', 'Too many requests, retry later');
}

// --- Profil -------------------------------------------------------------------

final class InvalidTimezoneException extends AppException {
  const InvalidTimezoneException()
    : super('invalid-timezone', 'Unknown IANA time zone');
}

// --- Agenda -------------------------------------------------------------------

final class EventNotFoundException extends AppException {
  const EventNotFoundException()
    : super('event-not-found', 'Event not found or not yours');
}

final class InvalidRangeException extends AppException {
  const InvalidRangeException()
    : super('invalid-range', 'Agenda range longer than a quarter');
}

final class CalendarNotFoundException extends AppException {
  const CalendarNotFoundException()
    : super('calendar-not-found', 'Calendar not found or not yours');
}

/// Le dernier agenda natif ne se supprime pas : les rdv s'y créent.
final class LastNativeCalendarException extends AppException {
  const LastNativeCalendarException()
    : super('last-native-calendar', 'The last native calendar cannot go');
}

// --- Transverse ---------------------------------------------------------------

final class NetworkException extends AppException {
  const NetworkException() : super('network', 'Server unreachable');
}

/// Repli quand aucune traduction plus précise n'existe.
final class UnknownException extends AppException {
  const UnknownException() : super('unknown', 'Something went wrong');
}
