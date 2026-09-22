import 'package:agora/src/features/groups/domain/free_slots.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:flutter_test/flutter_test.dart';

// Lundi 5 octobre 2026, heure locale de la machine de test : la fonction
// travaille en heure locale, les attendus aussi.
DateTime _day(int day, [int hour = 0, int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

GroupAgendaItem _busy(
  String userId,
  DateTime start,
  DateTime end, {
  bool allDay = false,
}) => GroupAgendaItem(
  userId: userId,
  level: ShareLevel.busy,
  start: allDay
      ? DateTime.utc(start.year, start.month, start.day)
      : start.toUtc(),
  end: allDay ? DateTime.utc(end.year, end.month, end.day) : end.toUtc(),
  isAllDay: allDay,
);

GroupAgendaItem _groupEvent(DateTime start, DateTime end) => GroupAgendaItem(
  eventId: 'evt',
  isGroupEvent: true,
  level: ShareLevel.details,
  title: 'Match',
  start: start.toUtc(),
  end: end.toUtc(),
  isAllDay: false,
);

/// Lundi 5 → mercredi 7 octobre, de 18 h à 22 h, une heure au moins.
SlotSearch _search({
  Duration duration = const Duration(hours: 1),
  Set<String> members = const {'a', 'b'},
  Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
  bool allDayBlocks = false,
  int to = 8,
}) => SlotSearch(
  from: _day(5),
  to: _day(to),
  duration: duration,
  dayStart: const Duration(hours: 18),
  dayEnd: const Duration(hours: 22),
  weekdays: weekdays,
  members: members,
  allDayBlocks: allDayBlocks,
);

String _show(List<FreeSlot> slots) => [
  for (final s in slots)
    '${s.start.day} ${s.start.hour}:${s.start.minute.toString().padLeft(2, '0')}'
        '-${s.end.hour}:${s.end.minute.toString().padLeft(2, '0')}',
].join(', ');

void main() {
  test('an empty agenda leaves every evening free', () {
    expect(
      _show(findFreeSlots(_search(), const [])),
      '5 18:00-22:00, 6 18:00-22:00, 7 18:00-22:00',
    );
  });

  test('anyone busy takes the slot away, overlaps merged', () {
    final slots = findFreeSlots(_search(), [
      _busy('a', _day(5, 18), _day(5, 19)),
      _busy('b', _day(5, 18, 30), _day(5, 20)),
      _busy('a', _day(6, 20), _day(6, 23)),
    ]);

    expect(_show(slots), '5 20:00-22:00, 6 18:00-20:00, 7 18:00-22:00');
  });

  test('a gap shorter than the duration is not a slot', () {
    final slots = findFreeSlots(_search(duration: const Duration(hours: 2)), [
      // Restent 18 h–19 h et 20 h 30–22 h : trop courts pour deux heures.
      _busy('a', _day(5, 19), _day(5, 20, 30)),
    ]);

    expect(_show(slots).startsWith('5'), isFalse);
  });

  test('only the chosen members count', () {
    final slots = findFreeSlots(_search(members: {'a'}), [
      _busy('b', _day(5, 18), _day(5, 22)),
    ]);

    expect(_show(slots).startsWith('5 18:00-22:00'), isTrue);
  });

  test('an event of the group takes the slot for everyone', () {
    final slots = findFreeSlots(_search(), [
      _groupEvent(_day(7, 18), _day(7, 21)),
    ]);

    expect(_show(slots).endsWith('7 21:00-22:00'), isTrue);
  });

  test('all-day events leave the day free, unless asked otherwise', () {
    final holiday = _busy('a', _day(6), _day(7), allDay: true);

    expect(
      _show(findFreeSlots(_search(), [holiday])),
      contains('6 18:00-22:00'),
    );
    expect(
      _show(findFreeSlots(_search(allDayBlocks: true), [holiday])),
      isNot(contains('6 ')),
    );
  });

  test('days outside the chosen weekdays are skipped', () {
    // Lundi 5 et mercredi 7 seulement.
    final slots = findFreeSlots(_search(weekdays: {1, 3}), const []);

    expect(_show(slots), '5 18:00-22:00, 7 18:00-22:00');
  });

  test('a window crossing midnight is not supported: it is empty', () {
    final search = SlotSearch(
      from: _day(5),
      to: _day(6),
      duration: const Duration(hours: 1),
      dayStart: const Duration(hours: 22),
      dayEnd: const Duration(hours: 2),
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      members: const {'a'},
    );

    expect(findFreeSlots(search, const []), isEmpty);
  });

  test('the past is never offered', () {
    final search = SlotSearch(
      from: _day(5, 19, 10),
      to: _day(6),
      duration: const Duration(minutes: 30),
      dayStart: const Duration(hours: 18),
      dayEnd: const Duration(hours: 22),
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      members: const {'a'},
    );

    // Le créneau commence au quart d'heure suivant « maintenant ».
    expect(_show(findFreeSlots(search, const [])), '5 19:15-22:00');
  });

  test('results are capped', () {
    final search = SlotSearch(
      from: _day(1),
      to: DateTime(2027, 3, 1),
      duration: const Duration(hours: 1),
      dayStart: const Duration(hours: 8),
      dayEnd: const Duration(hours: 22),
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      members: const {'a'},
    );

    expect(findFreeSlots(search, const []), hasLength(maxFreeSlots));
  });
}
