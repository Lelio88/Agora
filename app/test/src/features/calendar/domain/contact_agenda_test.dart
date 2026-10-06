import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/contact_agenda.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un rdv « journée entière » le [day] (date de calendrier, minuit UTC).
AgendaItem _allDay(
  String id,
  DateTime day, {
  String calendarId = 'cal-lea',
  String? rrule = 'FREQ=YEARLY',
  String title = 'Anniversaire de Léa',
}) => AgendaItem(
  eventId: id,
  seriesId: rrule == null ? null : id,
  originalStart: rrule == null
      ? null
      : DateTime.utc(day.year, day.month, day.day),
  calendarId: calendarId,
  title: title,
  start: DateTime.utc(day.year, day.month, day.day),
  end: DateTime.utc(day.year, day.month, day.day + 1),
  isAllDay: true,
  timezone: 'Europe/Paris',
  rrule: rrule,
);

AgendaItem _timed(String id, DateTime start, DateTime end) => AgendaItem(
  eventId: id,
  calendarId: 'cal-lea',
  title: id,
  start: start.toUtc(),
  end: end.toUtc(),
  isAllDay: false,
  timezone: 'Europe/Paris',
);

void main() {
  final today = DateTime(2026, 10, 5, 14);

  group('upcomingAnniversaries', () {
    test('keeps the yearly all-day dates of close ones, soonest first', () {
      final result = upcomingAnniversaries(
        [
          _allDay('b', DateTime(2026, 10, 20), title: 'Anniversaire de Max'),
          _allDay('a', DateTime(2026, 10, 8)),
        ],
        contactCalendarIds: {'cal-lea'},
        today: today,
      );

      expect(result.map((a) => a.item.eventId), ['a', 'b']);
      expect(result.map((a) => a.daysAway), [3, 15]);
    });

    test("today's date is zero days away", () {
      final result = upcomingAnniversaries(
        [_allDay('a', DateTime(2026, 10, 5))],
        contactCalendarIds: {'cal-lea'},
        today: today,
      );

      expect(result.single.daysAway, 0);
    });

    test('ignores my own dates, one-off days and timed events', () {
      final result = upcomingAnniversaries(
        [
          _allDay('mine', DateTime(2026, 10, 8), calendarId: 'cal-me'),
          _allDay('once', DateTime(2026, 10, 8), rrule: null),
          _allDay('weekly', DateTime(2026, 10, 8), rrule: 'FREQ=WEEKLY'),
          _timed('work', DateTime(2026, 10, 8, 9), DateTime(2026, 10, 8, 17)),
        ],
        contactCalendarIds: {'cal-lea'},
        today: today,
      );

      expect(result, isEmpty);
    });

    test('ignores dates already past', () {
      final result = upcomingAnniversaries(
        [_allDay('a', DateTime(2026, 10, 4))],
        contactCalendarIds: {'cal-lea'},
        today: today,
      );

      expect(result, isEmpty);
    });
  });

  group('contactMoment', () {
    test('tells what is on now and what comes next', () {
      final moment = contactMoment([
        _timed('Travail', DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 17)),
        _timed('Sport', DateTime(2026, 10, 5, 18), DateTime(2026, 10, 5, 19)),
        _timed('Hier', DateTime(2026, 10, 4, 9), DateTime(2026, 10, 4, 17)),
      ], now: today);

      expect(moment.current.map((i) => i.title), ['Travail']);
      expect(moment.next?.title, 'Sport');
    });

    test('an all-day date counts for the whole day', () {
      final moment = contactMoment([
        _allDay('rest', DateTime(2026, 10, 5), rrule: null, title: 'Repos'),
      ], now: today);

      expect(moment.current.map((i) => i.title), ['Repos']);
      expect(moment.next, isNull);
    });

    test('nothing noted leaves both empty', () {
      final moment = contactMoment(const [], now: today);

      expect(moment.current, isEmpty);
      expect(moment.next, isNull);
    });
  });
}
