import 'dart:async';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/calendar/domain/calendars_repository.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';

import 'fake_calendar_repository.dart';

/// Faux [CalendarsRepository] en mémoire. Par défaut, l'utilisateur a son
/// seul agenda d'inscription, celui du faux dépôt d'agenda. Comme le
/// serveur, il refuse de supprimer le dernier agenda natif.
class FakeCalendarsRepository implements CalendarsRepository {
  FakeCalendarsRepository([List<UserCalendar>? calendars])
    : _calendars = [
        ...calendars ??
            [
              const UserCalendar(
                id: FakeCalendarRepository.calendarId,
                name: 'Agenda',
                kind: CalendarKind.native,
              ),
            ],
      ];

  final List<UserCalendar> _calendars;
  final _changes = StreamController<int>.broadcast();
  final calls = <String>[];
  int _ticks = 0;

  /// Liens reçus par [importCalendar], dans l'ordre.
  final importedUrls = <String>[];

  /// Nombre de rdv annoncé avant une suppression, par agenda.
  final eventCounts = <String, int>{};
  AppException? nextError;
  int _nextId = 1;

  List<UserCalendar> get calendars => List.unmodifiable(_calendars);

  void _record(String call) {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  /// Simule un changement venu du serveur (par exemple une synchro faite
  /// par le worker) : remplace l'agenda et émet un tick.
  void pushFromServer(UserCalendar calendar) {
    final index = _calendars.indexWhere((c) => c.id == calendar.id);
    if (index < 0) {
      _calendars.add(calendar);
    } else {
      _calendars[index] = calendar;
    }
    _changes.add(++_ticks);
  }

  @override
  Stream<int> watchChanges() => _changes.stream;

  /// Ne pas attendre la fermeture (voir FakeCalendarRepository.dispose).
  void dispose() {
    unawaited(_changes.close());
  }

  @override
  Future<List<UserCalendar>> fetchCalendars() async {
    _record('fetchCalendars');
    return List.unmodifiable(_calendars);
  }

  @override
  Future<void> createCalendar(CalendarDraft draft) async {
    _record('createCalendar');
    _calendars.add(
      UserCalendar(
        id: 'cal-new-${_nextId++}',
        name: draft.name.trim(),
        kind: CalendarKind.native,
        colorHex: draft.colorHex,
        visibility: draft.visibility,
      ),
    );
  }

  /// Comme `add_ics_calendar` : lien vérifié, dix agendas importés au plus.
  @override
  Future<void> importCalendar(ImportedCalendarDraft draft) async {
    _record('importCalendar');
    if (!looksLikeFeedUrl(draft.url)) throw const InvalidFeedUrlException();
    if (_calendars.where((c) => c.isImported).length >= 10) {
      throw const TooManyFeedsException();
    }
    importedUrls.add(draft.url);
    _calendars.add(
      UserCalendar(
        id: 'cal-ics-${_nextId++}',
        name: draft.name.trim(),
        kind: CalendarKind.ics,
        colorHex: draft.colorHex,
      ),
    );
  }

  @override
  Future<void> syncNow(String calendarId) async {
    _record('syncNow');
    if (!_calendars[_indexOf(calendarId)].isImported) {
      throw const CalendarNotFoundException();
    }
  }

  @override
  Future<void> updateCalendar(String calendarId, CalendarDraft draft) async {
    _record('updateCalendar');
    final index = _indexOf(calendarId);
    final old = _calendars[index];
    _calendars[index] = UserCalendar(
      id: old.id,
      name: draft.name.trim(),
      kind: old.kind,
      colorHex: draft.colorHex,
      visibility: draft.visibility,
      groupId: old.groupId,
      hidden: old.hidden,
      lastSyncedAt: old.lastSyncedAt,
      syncError: old.syncError,
    );
  }

  @override
  Future<void> deleteCalendar(String calendarId) async {
    _record('deleteCalendar');
    final calendar = _calendars[_indexOf(calendarId)];
    final natives = _calendars.where((c) => c.kind == CalendarKind.native);
    if (calendar.kind == CalendarKind.native && natives.length <= 1) {
      throw const LastNativeCalendarException();
    }
    _calendars.removeWhere((c) => c.id == calendarId);
  }

  @override
  Future<void> setHidden(String calendarId, {required bool hidden}) async {
    _record('setHidden');
    final index = _indexOf(calendarId);
    _calendars[index] = _calendars[index].copyWith(hidden: hidden);
  }

  @override
  Future<int> countEvents(String calendarId) async {
    _record('countEvents');
    return eventCounts[calendarId] ?? 0;
  }

  int _indexOf(String calendarId) {
    final index = _calendars.indexWhere((c) => c.id == calendarId);
    if (index < 0) throw const CalendarNotFoundException();
    return index;
  }
}
