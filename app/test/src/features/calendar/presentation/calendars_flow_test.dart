import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fake_calendars_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

const _personal = UserCalendar(
  id: FakeCalendarRepository.calendarId,
  name: 'Agenda',
  kind: CalendarKind.native,
);
const _work = UserCalendar(
  id: 'cal-work',
  name: 'Travail',
  kind: CalendarKind.native,
  colorHex: '#1E88E5',
);

/// Mardi de la semaine affichée par défaut (elle commence le lundi), à 18 h
/// locales : visible quel que soit le jour du test. Un « prochain mardi »
/// tombait la semaine suivante un mardi après 18 h.
DateTime _tuesdayThisWeek18h() {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + 1, 18).toUtc();
}

AgendaItem _meeting() {
  final start = _tuesdayThisWeek18h();
  return AgendaItem(
    eventId: 'evt-meeting',
    calendarId: _work.id,
    title: 'Réunion',
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'Europe/Paris',
  );
}

void main() {
  testWidgets('creating a calendar adds it to my calendars', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    robot.expectScreen(CalendarKeys.calendarsScreen);
    await robot.tap(CalendarKeys.newCalendar);
    await robot.enter(CalendarKeys.calendarName, 'Sport');
    await robot.tap(CalendarKeys.calendarColor('#43A047'));
    await robot.tap(CalendarKeys.calendarSave);

    final created = robot.calendars.calendars.last;
    expect(created.name, 'Sport');
    expect(created.colorHex, '#43A047');
    expect(find.text('Sport'), findsOneWidget);
    robot.expectText('Agenda enregistré.');
  });

  testWidgets('a calendar name is required', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    await robot.tap(CalendarKeys.newCalendar);
    await robot.tap(CalendarKeys.calendarSave);

    robot.expectText('Entre 1 et 60 caractères.');
    expect(robot.calendars.calls, isNot(contains('createCalendar')));
  });

  testWidgets('unchecking a calendar hides its events from my agenda', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()..seed(_meeting()),
      calendars: FakeCalendarsRepository([_personal, _work]),
    );
    expect(find.text('Réunion'), findsWidgets);

    await robot.openCalendars();
    await robot.tap(CalendarKeys.calendarShown(_work.id));
    await robot.goBack();

    expect(find.text('Réunion'), findsNothing);
    expect(robot.calendars.calendars.last.hidden, isTrue);
  });

  testWidgets('deleting a calendar announces how many events go with it', (
    tester,
  ) async {
    final calendars = FakeCalendarsRepository([_personal, _work])
      ..eventCounts[_work.id] = 3;
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: calendars);

    await robot.openCalendars();
    await robot.tap(CalendarKeys.calendarTile(_work.id));
    await robot.tap(CalendarKeys.calendarDelete);
    robot.expectText('Supprimer « Travail » ?');
    robot.expectText(
      'Ses 3 rendez-vous seront supprimés avec lui, définitivement.',
    );
    await robot.tap(CalendarKeys.confirmDeleteCalendar);

    expect(calendars.calendars.map((c) => c.id), [_personal.id]);
    robot.expectText('Agenda supprimé.');
  });

  testWidgets('my only calendar cannot be deleted', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    await robot.tap(CalendarKeys.calendarTile(_personal.id));

    expect(find.byKey(CalendarKeys.calendarDelete), findsNothing);
    robot.expectText('Votre seul agenda ne peut pas être supprimé.');
  });

  testWidgets('the event editor files a new event in the chosen calendar', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _work]),
    );

    await robot.openNewEvent();
    await robot.enter(CalendarKeys.title, 'Réunion');
    await robot.chooseCalendar(_work.id);
    await robot.tap(CalendarKeys.save);

    expect(robot.calendar.items.single.calendarId, _work.id);
  });

  testWidgets('moving a series to another calendar moves the whole series', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository();
    final start = _tuesdayThisWeek18h();
    await calendar.createEvent(
      EventDraft(
        calendarId: _personal.id,
        title: 'Yoga',
        start: start,
        end: start.add(const Duration(hours: 1)),
        timezone: 'Europe/Paris',
        recurrence: const RecurrenceRule(frequency: Frequency.weekly),
      ),
    );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: calendar,
      calendars: FakeCalendarsRepository([_personal, _work]),
    );

    await robot.tapEvent('Yoga');
    await robot.chooseCalendar(_work.id);
    await robot.tap(CalendarKeys.save);

    robot.expectText(
      'Changer d\'agenda s\'applique toujours à toute la série.',
    );
    expect(find.byKey(CalendarKeys.scopeOccurrence), findsNothing);
    await robot.tap(CalendarKeys.scopeSeries);

    expect(calendar.writes.last, 'updateSeries');
    expect(calendar.items.every((i) => i.calendarId == _work.id), isTrue);
  });

  testWidgets('an event takes the color of its calendar', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()..seed(_meeting()),
      calendars: FakeCalendarsRepository([_personal, _work]),
    );

    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Réunion').first,
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = tile.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF1E88E5));
  });
}
