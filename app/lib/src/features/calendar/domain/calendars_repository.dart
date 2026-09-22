/// Accès aux agendas de l'utilisateur : liste, création, réglages,
/// suppression et préférence d'affichage.
///
/// Invariants : seules des `AppException` en sortent ; supprimer un agenda
/// supprime ses rdv, et le dernier agenda natif ne se supprime pas
/// (`LastNativeCalendarException`) — c'est là que se créent les rdv.
library;

import 'package:agora/src/features/calendar/domain/user_calendar.dart';

abstract interface class CalendarsRepository {
  /// Agendas lisibles, du plus ancien au plus récent : le premier agenda où
  /// l'on peut écrire est l'agenda par défaut.
  Future<List<UserCalendar>> fetchCalendars();

  Future<void> createCalendar(CalendarDraft draft);

  Future<void> updateCalendar(String calendarId, CalendarDraft draft);

  /// Supprime l'agenda et tous ses rdv.
  Future<void> deleteCalendar(String calendarId);

  /// Masque ou réaffiche l'agenda dans la vue de l'utilisateur seulement.
  Future<void> setHidden(String calendarId, {required bool hidden});

  /// Nombre de rdv de l'agenda (une série compte pour un), pour prévenir
  /// avant de le supprimer.
  Future<int> countEvents(String calendarId);
}
