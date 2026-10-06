import 'dart:async';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/calendars_repository.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';

import 'fake_calendar_repository.dart';

/// Faux [CalendarsRepository] en mémoire. Par défaut, l'utilisateur a son
/// seul agenda d'inscription, celui du faux dépôt d'agenda. Comme le
/// serveur, il refuse de supprimer le dernier agenda natif, ne relie un
/// proche qu'à un co-membre ([coMembers]), un seul proche par membre, et
/// donne au proche relié le nom du membre.
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

  /// Les co-membres de l'utilisateur et leur nom : les seuls qu'un proche
  /// peut désigner.
  final coMembers = <String, String>{};
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
  Future<String> createCalendar(CalendarDraft draft) async {
    _record('createCalendar');
    final id = 'cal-new-${_nextId++}';
    _calendars.add(
      UserCalendar(
        id: id,
        name: draft.name.trim(),
        kind: CalendarKind.native,
        colorHex: draft.colorHex,
        visibility: draft.isContact
            ? EventVisibility.invisible
            : draft.visibility,
        isContact: draft.isContact,
      ),
    );
    return id;
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
        visibility: draft.isContact ? EventVisibility.invisible : null,
        isContact: draft.isContact,
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
      visibility: old.isContact ? EventVisibility.invisible : draft.visibility,
      groupId: old.groupId,
      hidden: old.hidden,
      lastSyncedAt: old.lastSyncedAt,
      syncError: old.syncError,
      isContact: old.isContact,
      contactUserId: old.contactUserId,
    );
  }

  @override
  Future<void> linkContact(String calendarId, String? userId) async {
    _record('linkContact');
    final index = _indexOf(calendarId);
    final old = _calendars[index];
    if (!old.isContact) throw const CalendarNotFoundException();
    final name = userId == null ? old.name : coMembers[userId];
    if (name == null) throw const NotCoMemberException();
    if (userId != null &&
        _calendars.any((c) => c.contactUserId == userId && c.id != old.id)) {
      throw const ContactAlreadyLinkedException();
    }
    _calendars[index] = _withLink(old, userId, name);
  }

  @override
  Future<String> createMemberContact(String userId) async {
    _record('createMemberContact');
    final name = coMembers[userId];
    if (name == null) throw const NotCoMemberException();
    final existing = _calendars.where((c) => c.contactUserId == userId);
    if (existing.isNotEmpty) return existing.first.id;
    final id = 'cal-new-${_nextId++}';
    _calendars.add(
      UserCalendar(
        id: id,
        name: name,
        kind: CalendarKind.native,
        visibility: EventVisibility.invisible,
        isContact: true,
        contactUserId: userId,
      ),
    );
    return id;
  }

  static UserCalendar _withLink(
    UserCalendar old,
    String? userId,
    String name,
  ) => UserCalendar(
    id: old.id,
    name: name,
    kind: old.kind,
    colorHex: old.colorHex,
    visibility: old.visibility,
    groupId: old.groupId,
    hidden: old.hidden,
    lastSyncedAt: old.lastSyncedAt,
    syncError: old.syncError,
    isContact: old.isContact,
    contactUserId: userId,
  );

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
