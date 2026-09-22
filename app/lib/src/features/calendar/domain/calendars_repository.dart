/// Accès aux agendas de l'utilisateur : liste, création, import par lien
/// iCal, réglages, suppression et préférence d'affichage.
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

  /// Émet à chaque changement d'un agenda lisible (temps réel) : réglages
  /// faits ailleurs, état de synchro d'un agenda importé. Le compteur évite
  /// qu'un `==` avale un tick.
  Stream<int> watchChanges();

  Future<void> createCalendar(CalendarDraft draft);

  /// Importe un agenda par son lien iCal ; le serveur le relit ensuite seul.
  /// Lien refusé : `InvalidFeedUrlException` ; trop d'agendas importés :
  /// `TooManyFeedsException`.
  Future<void> importCalendar(ImportedCalendarDraft draft);

  /// Demande une relecture immédiate d'un agenda importé (sans effet si une
  /// relecture a eu lieu dans la dernière minute).
  Future<void> syncNow(String calendarId);

  Future<void> updateCalendar(String calendarId, CalendarDraft draft);

  /// Supprime l'agenda et tous ses rdv.
  Future<void> deleteCalendar(String calendarId);

  /// Masque ou réaffiche l'agenda dans la vue de l'utilisateur seulement.
  Future<void> setHidden(String calendarId, {required bool hidden});

  /// Nombre de rdv de l'agenda (une série compte pour un), pour prévenir
  /// avant de le supprimer.
  Future<int> countEvents(String calendarId);
}
