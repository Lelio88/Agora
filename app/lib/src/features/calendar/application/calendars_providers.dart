/// Agendas de l'utilisateur : liste, agenda par défaut, et le service qui
/// les crée, règle, masque et supprime.
///
/// Choix non évident : chaque action réussie invalide elle-même la liste
/// (et l'agenda, qui en dépend) : `calendars` n'est pas publiée en temps
/// réel, et l'utilisateur doit voir sa modification tout de suite.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/domain/calendars_repository.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarsRepositoryProvider = Provider<CalendarsRepository>(
  (ref) => throw UnimplementedError(
    'calendarsRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Agendas lisibles, du plus ancien au plus récent.
final calendarsProvider = FutureProvider<List<UserCalendar>>(
  (ref) => ref.watch(calendarsRepositoryProvider).fetchCalendars(),
);

/// Agenda où se créent les rdv : le plus ancien où l'on peut écrire (celui
/// de l'inscription tant qu'il existe). Le serveur en garantit toujours un.
final defaultCalendarIdProvider = FutureProvider<String>((ref) async {
  final calendars = await ref.watch(calendarsProvider.future);
  final writable = calendars.where((c) => c.isWritable).firstOrNull;
  if (writable == null) throw const CalendarNotFoundException();
  return writable.id;
});

final class CalendarsService {
  const CalendarsService(this._repository, this._onChanged);

  final CalendarsRepository _repository;

  /// Appelé après chaque action réussie (invalide agendas et agenda).
  final void Function() _onChanged;

  Future<void> create(CalendarDraft draft) =>
      _then(_repository.createCalendar(draft));

  Future<void> update(String calendarId, CalendarDraft draft) =>
      _then(_repository.updateCalendar(calendarId, draft));

  Future<void> delete(String calendarId) =>
      _then(_repository.deleteCalendar(calendarId));

  Future<void> setHidden(String calendarId, {required bool hidden}) =>
      _then(_repository.setHidden(calendarId, hidden: hidden));

  Future<int> countEvents(String calendarId) =>
      _repository.countEvents(calendarId);

  Future<void> _then(Future<void> action) async {
    await action;
    _onChanged();
  }
}

final calendarsServiceProvider = Provider<CalendarsService>(
  (ref) => CalendarsService(ref.watch(calendarsRepositoryProvider), () {
    ref
      ..invalidate(calendarsProvider)
      ..invalidate(agendaProvider);
  }),
);
