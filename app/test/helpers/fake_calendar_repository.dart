import 'dart:async';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';

/// Faux [CalendarRepository] en mémoire. Il imite le serveur au plus près
/// de ce que l'app observe : une série créée apparaît par ses occurrences
/// hebdomadaires (dépliage minimal, 8 semaines), une occurrence modifiée
/// remplace la sienne, une occurrence supprimée disparaît. Modifier toute
/// la série la décale d'autant que l'occurrence touchée ; un nouvel horaire
/// efface ses occurrences modifiées, comme le serveur.
class FakeCalendarRepository implements CalendarRepository {
  static const calendarId = 'cal-1';

  final _items = <String, AgendaItem>{};
  final _changes = StreamController<int>.broadcast();
  final calls = <String>[];

  /// Les appels qui modifient quelque chose (sans les relectures).
  List<String> get writes =>
      calls.where((c) => c != 'fetchAgenda').toList(growable: false);
  AppException? nextError;
  int _ticks = 0;
  int _nextId = 1;

  List<AgendaItem> get items =>
      _items.values.toList()..sort((a, b) => a.start.compareTo(b.start));

  void seed(AgendaItem item) => _items[item.instanceKey] = item;

  /// Faux temps réel : coupé, l'agenda ne doit compter que sur lui-même
  /// pour se rafraîchir après une action.
  bool realtimeEnabled = true;

  void _notify() {
    if (realtimeEnabled) _changes.add(++_ticks);
  }

  Future<void> _record(String call) async {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  Future<List<AgendaItem>> fetchAgenda(DateTime from, DateTime to) async {
    await _record('fetchAgenda');
    return items
        .where((i) => i.start.isBefore(to) && i.end.isAfter(from))
        .toList();
  }

  @override
  Stream<int> watchChanges() => _changes.stream;

  @override
  Future<void> createEvent(EventDraft draft) async {
    await _record('createEvent');
    final id = 'evt-${_nextId++}';
    if (draft.recurrence == null) {
      seed(_item(id, draft, draft.start, draft.end));
    } else {
      for (var week = 0; week < 8; week++) {
        final start = draft.start.add(Duration(days: 7 * week));
        final end = draft.end.add(Duration(days: 7 * week));
        seed(_item(id, draft, start, end, seriesId: id, originalStart: start));
      }
    }
    _notify();
  }

  @override
  Future<void> updateEvent(String eventId, EventDraft draft) async {
    await _record('updateEvent');
    final existing = _items.values.where((i) => i.eventId == eventId).toList();
    for (final item in existing) {
      _items.remove(item.instanceKey);
      final shift = item.start.difference(existing.first.start);
      seed(
        _item(
          eventId,
          draft,
          draft.start.add(shift),
          draft.end.add(shift),
          seriesId: item.seriesId,
          originalStart: item.originalStart == null
              ? null
              : draft.start.add(shift),
        ),
      );
    }
    _notify();
  }

  /// Dernier appel à [updateSeries], pour les tests du service.
  ({
    String seriesId,
    DateTime occurrenceStart,
    EventDraft draft,
    bool followWeekdays,
  })?
  lastSeriesUpdate;

  @override
  Future<void> updateSeries({
    required String seriesId,
    required DateTime occurrenceStart,
    required EventDraft draft,
    required bool followWeekdays,
  }) async {
    await _record('updateSeries');
    lastSeriesUpdate = (
      seriesId: seriesId,
      occurrenceStart: occurrenceStart,
      draft: draft,
      followWeekdays: followWeekdays,
    );
    final shift = draft.start.difference(occurrenceStart);
    final duration = draft.end.difference(draft.start);
    final instances = _items.values
        .where((i) => i.seriesId == seriesId)
        .toList();
    final firstLength = instances
        .where((i) => i.kind == InstanceKind.seriesOccurrence)
        .map((i) => i.end.difference(i.start))
        .firstOrNull;
    final scheduleChanged = shift != Duration.zero || duration != firstLength;
    for (final item in instances) {
      _items.remove(item.instanceKey);
      if (item.kind == InstanceKind.modifiedOccurrence) {
        if (!scheduleChanged) {
          seed(_copy(item, calendarId: draft.calendarId));
        }
        continue;
      }
      final start = item.start.add(shift);
      seed(
        _item(
          seriesId,
          draft,
          start,
          start.add(duration),
          seriesId: seriesId,
          originalStart: start,
        ),
      );
    }
    _notify();
  }

  @override
  Future<void> updateOccurrence({
    required String seriesId,
    required DateTime originalStart,
    required EventDraft draft,
  }) async {
    await _record('updateOccurrence');
    _items.removeWhere(
      (_, i) => i.seriesId == seriesId && i.originalStart == originalStart,
    );
    seed(
      _item(
        'evt-${_nextId++}',
        draft,
        draft.start,
        draft.end,
        seriesId: seriesId,
        originalStart: originalStart,
      ),
    );
    _notify();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await _record('deleteEvent');
    _items.removeWhere((_, i) => i.eventId == eventId || i.seriesId == eventId);
    _notify();
  }

  @override
  Future<void> deleteOccurrence({
    required String seriesId,
    required DateTime originalStart,
  }) async {
    await _record('deleteOccurrence');
    _items.removeWhere(
      (_, i) => i.seriesId == seriesId && i.originalStart == originalStart,
    );
    _notify();
  }

  AgendaItem _item(
    String id,
    EventDraft draft,
    DateTime start,
    DateTime end, {
    String? seriesId,
    DateTime? originalStart,
  }) => AgendaItem(
    eventId: id,
    seriesId: seriesId,
    originalStart: originalStart,
    calendarId: draft.calendarId,
    title: draft.title,
    location: draft.location,
    description: draft.description,
    start: start,
    end: end,
    isAllDay: draft.isAllDay,
    timezone: draft.timezone,
    rrule: draft.rrule,
    visibility: draft.visibility,
  );

  /// Comme le serveur, ne touche que la ligne visée : une série depuis
  /// l'une de ses occurrences, pas ses occurrences modifiées.
  @override
  Future<void> setEventVisibility(
    String eventId,
    EventVisibility? visibility,
  ) async {
    await _record('setEventVisibility');
    final targets = _items.values.where((i) => i.eventId == eventId).toList();
    if (targets.isEmpty) throw const EventNotFoundException();
    for (final item in targets) {
      seed(_copy(item, visibility: () => visibility));
    }
    _notify();
  }

  /// [visibility] est une fonction pour distinguer « inchangée » (absente)
  /// de « selon le groupe » (`null`).
  AgendaItem _copy(
    AgendaItem item, {
    String? calendarId,
    EventVisibility? Function()? visibility,
  }) => AgendaItem(
    eventId: item.eventId,
    seriesId: item.seriesId,
    originalStart: item.originalStart,
    calendarId: calendarId ?? item.calendarId,
    title: item.title,
    location: item.location,
    description: item.description,
    start: item.start,
    end: item.end,
    isAllDay: item.isAllDay,
    timezone: item.timezone,
    rrule: item.rrule,
    visibility: visibility == null ? item.visibility : visibility(),
  );

  /// Ne pas attendre la fermeture : `close()` d'un flux broadcast n'aboutit
  /// qu'une fois tous les abonnés partis, ce qui dépend de l'ordre des
  /// teardowns et bloquerait le test 30 s.
  void dispose() {
    unawaited(_changes.close());
  }
}
