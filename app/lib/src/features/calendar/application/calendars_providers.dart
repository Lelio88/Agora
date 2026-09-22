/// Agendas de l'utilisateur : liste, agenda par défaut, et le service qui
/// les crée, importe, règle, masque, relance et supprime.
///
/// Choix non évidents :
/// - chaque action réussie invalide elle-même la liste (et l'agenda, qui
///   en dépend) : l'utilisateur doit voir sa modification tout de suite,
///   même si le temps réel manque (coupure, pile locale sans Realtime) ;
/// - la liste suit aussi le temps réel de `calendars` : l'état de synchro
///   d'un agenda importé change sans que l'utilisateur ait rien fait.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/domain/calendars_repository.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final calendarsRepositoryProvider = Provider<CalendarsRepository>(
  (ref) => throw UnimplementedError(
    'calendarsRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Compteur de changements côté serveur ; chaque tick recharge la liste.
/// Réabonné à chaque changement de compte ; rien sans compte.
final calendarsChangesProvider = StreamProvider<int>((ref) async* {
  final repository = ref.watch(calendarsRepositoryProvider);
  if (await ref.watch(currentUserIdProvider.future) == null) return;
  yield* repository.watchChanges();
});

/// Agendas lisibles, du plus ancien au plus récent ; relus à chaque
/// changement de compte. Sans compte, aucun : pas de requête anonyme, que
/// le serveur refuserait.
final calendarsProvider = FutureProvider<List<UserCalendar>>((ref) async {
  final repository = ref.watch(calendarsRepositoryProvider);
  ref.watch(calendarsChangesProvider);
  if (await ref.watch(currentUserIdProvider.future) == null) return const [];
  return repository.fetchCalendars();
});

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

  Future<void> import(ImportedCalendarDraft draft) =>
      _then(_repository.importCalendar(draft));

  /// Relance la synchro d'un agenda importé. L'état affiché ne change
  /// qu'une fois le worker passé : la liste se relit tout de suite quand
  /// même, pour montrer une erreur déjà levée.
  Future<void> syncNow(String calendarId) =>
      _then(_repository.syncNow(calendarId));

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
