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

/// Une occurrence des horaires de travail de Léa (série hebdomadaire).
AgendaItem _work(
  DateTime start,
  DateTime end, {
  String rrule = 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
  String? location,
  String? description,
}) => AgendaItem(
  eventId: 'work',
  seriesId: 'work',
  originalStart: start.toUtc(),
  calendarId: 'cal-lea',
  title: 'Travail',
  start: start.toUtc(),
  end: end.toUtc(),
  isAllDay: false,
  timezone: 'Europe/Paris',
  rrule: rrule,
  location: location,
  description: description,
);

/// Un congé de [from] à [to] inclus.
AgendaItem _dayOff(DateTime from, DateTime to, {String? description}) =>
    AgendaItem(
      eventId: 'off-${from.day}',
      calendarId: 'cal-lea',
      title: 'Congé',
      start: DateTime.utc(from.year, from.month, from.day),
      end: DateTime.utc(to.year, to.month, to.day + 1),
      isAllDay: true,
      timezone: 'Europe/Paris',
      description: description,
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

  group('contactFormFor', () {
    test('a plain yearly all-day date is a birthday', () {
      expect(
        contactFormFor(_allDay('a', DateTime(2026, 3, 12))),
        ContactEventKind.birthday,
      );
    });

    test('a timed weekly series is work hours, even with a place', () {
      expect(
        contactFormFor(
          _work(
            DateTime(2026, 10, 5, 9),
            DateTime(2026, 10, 5, 17),
            location: 'Boulangerie',
          ),
        ),
        ContactEventKind.workHours,
      );
    });

    test('a one-off all-day date is time off', () {
      expect(
        contactFormFor(_dayOff(DateTime(2026, 10, 5), DateTime(2026, 10, 9))),
        ContactEventKind.dayOff,
      );
    });

    test('anything the short form could not show opens the full editor', () {
      final unfit = {
        'notes': _dayOff(
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 5),
          description: 'Mariage',
        ),
        'birthday with an end': _allDay(
          'a',
          DateTime(2026, 3, 12),
          rrule: 'FREQ=YEARLY;UNTIL=20300101T000000Z',
        ),
        'every other week': _work(
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 17),
          rrule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO',
        ),
        'work with notes': _work(
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 17),
          description: "Badge à l'accueil",
        ),
        'advanced rule': _work(
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 17),
          rrule: 'FREQ=WEEKLY;BYSETPOS=1',
        ),
        'one-off timed': _timed(
          'Dentiste',
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 10),
        ),
        'daily': _work(
          DateTime(2026, 10, 5, 9),
          DateTime(2026, 10, 5, 17),
          rrule: 'FREQ=DAILY',
        ),
      };
      // Une occurrence modifiée sans la règle de sa série : le formulaire
      // court la réécrirait en rdv ponctuel, toute la série avec.
      unfit['occurrence without its rule'] = AgendaItem(
        eventId: 'moved',
        seriesId: 'work',
        originalStart: DateTime.utc(2026, 10, 5),
        calendarId: 'cal-lea',
        title: 'Congé',
        start: DateTime.utc(2026, 10, 5),
        end: DateTime.utc(2026, 10, 6),
        isAllDay: true,
        timezone: 'Europe/Paris',
      );
      unfit.forEach((name, item) {
        expect(contactFormFor(item), isNull, reason: name);
      });
    });
  });

  group('withoutWorkOnDaysOff', () {
    test('time off wins over work hours on the days it covers', () {
      final items = withoutWorkOnDaysOff([
        _work(DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 17)),
        _work(DateTime(2026, 10, 6, 9), DateTime(2026, 10, 6, 17)),
        _work(DateTime(2026, 10, 7, 9), DateTime(2026, 10, 7, 17)),
        _dayOff(DateTime(2026, 10, 5), DateTime(2026, 10, 6)),
      ]);

      expect(items.map((i) => (i.title, i.localStart.day)), [
        ('Travail', 7),
        ('Congé', 5),
      ]);
    });

    test('a birthday is no day off', () {
      final items = withoutWorkOnDaysOff([
        _work(DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 17)),
        _allDay('a', DateTime(2026, 10, 5)),
      ]);

      expect(items, hasLength(2));
    });
  });

  group('contactMoment rest day', () {
    test('a day without work hours is a rest day', () {
      final saturday = DateTime(2026, 10, 10, 11);
      final moment = contactMoment([
        _work(DateTime(2026, 10, 9, 9), DateTime(2026, 10, 9, 17)),
        _work(DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12, 17)),
      ], now: saturday);

      expect(moment.isRestDay, isTrue);
      expect(moment.current, isEmpty);
    });

    test('after hours on a work day is not a rest day', () {
      final evening = DateTime(2026, 10, 5, 20);
      final moment = contactMoment([
        _work(DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 17)),
      ], now: evening);

      expect(moment.isRestDay, isFalse);
    });

    test('without work hours noted, no day is a rest day', () {
      final moment = contactMoment([
        _allDay('a', DateTime(2026, 10, 8)),
      ], now: today);

      expect(moment.isRestDay, isFalse);
    });

    test('a night shift still running is no rest day', () {
      // Lundi 22 h – mardi 6 h ; le mardi n'est pas travaillé.
      final tuesdayNight = DateTime(2026, 10, 6, 3);
      final moment = contactMoment([
        _work(
          DateTime(2026, 10, 5, 22),
          DateTime(2026, 10, 6, 6),
          rrule: 'FREQ=WEEKLY;BYDAY=MO',
        ),
      ], now: tuesdayNight);

      expect(moment.current, hasLength(1));
      expect(moment.isRestDay, isFalse);
    });

    test('time off today shows itself rather than a rest day', () {
      final moment = contactMoment(
        withoutWorkOnDaysOff([
          _work(DateTime(2026, 10, 5, 9), DateTime(2026, 10, 5, 17)),
          _dayOff(DateTime(2026, 10, 5), DateTime(2026, 10, 5)),
        ]),
        now: today,
      );

      expect(moment.isRestDay, isFalse);
      expect(moment.current.map((i) => i.title), ['Congé']);
    });
  });
}
