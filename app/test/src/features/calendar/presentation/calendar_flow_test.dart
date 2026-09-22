import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

/// Mardi de la semaine affichée par défaut (elle commence le lundi), à 18 h
/// locales : visible quel que soit le jour du test. Un « prochain mardi »
/// tombait la semaine suivante un mardi après 18 h.
DateTime _tuesdayThisWeek18h() {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + 1, 18).toUtc();
}

AgendaItem _dentist() {
  final start = _tuesdayThisWeek18h();
  return AgendaItem(
    eventId: 'evt-dentist',
    calendarId: FakeCalendarRepository.calendarId,
    title: 'Dentiste',
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'Europe/Paris',
  );
}

Future<FakeCalendarRepository> _withWeeklyYoga() async {
  final calendar = FakeCalendarRepository();
  final start = _tuesdayThisWeek18h();
  await calendar.createEvent(
    EventDraft(
      calendarId: FakeCalendarRepository.calendarId,
      title: 'Yoga',
      start: start,
      end: start.add(const Duration(hours: 1)),
      timezone: 'Europe/Paris',
      recurrence: const RecurrenceRule(frequency: Frequency.weekly),
    ),
  );
  calendar.calls.clear();
  return calendar;
}

void main() {
  testWidgets('the home screen shows the agenda with its events', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository()..seed(_dentist());
    final robot = AgoraRobot(tester);

    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    robot.expectScreen(HomeKeys.screen);
    expect(find.text('Dentiste'), findsWidgets);
  });

  testWidgets('creating an event saves it and shows it', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openNewEvent();
    await robot.enter(CalendarKeys.title, 'Piscine');
    await robot.tap(CalendarKeys.save);

    expect(robot.calendar.writes, ['createEvent']);
    expect(robot.calendar.items.single.title, 'Piscine');
    robot.expectText('Rendez-vous enregistré.');
  });

  testWidgets('a weekly repeat creates a series', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openNewEvent();
    await robot.enter(CalendarKeys.title, 'Yoga');
    await robot.tap(CalendarKeys.repeat);
    await robot.tap(CalendarKeys.repeatOption(Frequency.weekly));
    await robot.tap(CalendarKeys.save);

    expect(robot.calendar.items.length, 8);
    expect(robot.calendar.items.first.rrule, 'FREQ=WEEKLY');
  });

  testWidgets('an empty title is refused offline', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openNewEvent();
    await robot.tap(CalendarKeys.save);

    expect(robot.calendar.writes, isEmpty);
    robot.expectText('Entre 1 et 200 caractères.');
  });

  testWidgets('editing one occurrence asks for the scope', (tester) async {
    final calendar = await _withWeeklyYoga();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.tapEvent('Yoga');
    await robot.enter(CalendarKeys.title, 'Yoga (décalé)');
    await robot.tap(CalendarKeys.save);
    robot.expectText(
      'Modifier seulement cette occurrence, ou toute la série ?',
    );
    await robot.tap(CalendarKeys.scopeOccurrence);

    expect(calendar.writes.last, 'updateOccurrence');
    expect(calendar.items.where((i) => i.title == 'Yoga (décalé)').length, 1);
    expect(calendar.items.where((i) => i.title == 'Yoga').length, 7);
  });

  testWidgets('deleting the whole series removes every occurrence', (
    tester,
  ) async {
    final calendar = await _withWeeklyYoga();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.tapEvent('Yoga');
    await robot.tap(CalendarKeys.delete);
    await robot.tap(CalendarKeys.scopeSeries);

    expect(calendar.writes.last, 'deleteEvent');
    expect(calendar.items, isEmpty);
    robot.expectText('Rendez-vous supprimé.');
  });

  testWidgets('saving an all-day event keeps its dates', (tester) async {
    final day = _tuesdayThisWeek18h().toLocal();
    final start = DateTime.utc(day.year, day.month, day.day);
    final calendar = FakeCalendarRepository()
      ..seed(
        AgendaItem(
          eventId: 'evt-holiday',
          calendarId: FakeCalendarRepository.calendarId,
          title: 'Congé',
          start: start,
          end: start.add(const Duration(days: 1)),
          isAllDay: true,
          timezone: 'Europe/Paris',
        ),
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.tapEvent('Congé');
    await robot.enter(CalendarKeys.title, 'Congé posé');
    await robot.tap(CalendarKeys.save);

    final saved = calendar.items.single;
    expect(saved.title, 'Congé posé');
    expect(saved.start, start, reason: 'the day must not move');
    expect(
      saved.end,
      start.add(const Duration(days: 1)),
      reason: 'a one-day event must not grow on every save',
    );
  });

  testWidgets('dragging an event moves it and keeps its length', (
    tester,
  ) async {
    final dentist = _dentist();
    final calendar = FakeCalendarRepository()..seed(dentist);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.dragEvent('Dentiste', const Offset(0, 150));

    expect(calendar.writes.last, 'updateEvent');
    final moved = calendar.items.single;
    // La case d'arrivée dépend de l'endroit où la tuile est saisie (kalender
    // part de son bord) : on vérifie qu'elle a bougé, pas où elle tombe.
    expect(moved.start, isNot(dentist.start));
    expect(moved.end.difference(moved.start), const Duration(hours: 1));
    robot.expectText('Rendez-vous déplacé.');
  });

  testWidgets(
    'dragging an occurrence asks the scope; cancelling puts it back',
    (tester) async {
      final calendar = await _withWeeklyYoga();
      final before = calendar.items.map((i) => i.start).toList();
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), calendar: calendar);

      await robot.dragEvent('Yoga', const Offset(0, 150));
      robot.expectText(
        'Déplacer seulement cette occurrence, ou toute la série ?',
      );
      await tester.tap(find.text('Annuler'));
      await robot.settle();

      expect(calendar.writes, isEmpty);
      expect(calendar.items.map((i) => i.start), before);
      expect(find.text('Yoga'), findsWidgets);
    },
  );

  testWidgets('dragging one occurrence moves only that occurrence', (
    tester,
  ) async {
    final calendar = await _withWeeklyYoga();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.dragEvent('Yoga', const Offset(0, 150));
    await robot.tap(CalendarKeys.scopeOccurrence);

    expect(calendar.writes.last, 'updateOccurrence');
    final moved = calendar.items.where(
      (i) => i.kind == InstanceKind.modifiedOccurrence,
    );
    expect(moved, hasLength(1));
    expect(moved.single.start, isNot(moved.single.originalStart));
  });

  testWidgets('a single event is deleted without asking for a scope', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository()..seed(_dentist());
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.tapEvent('Dentiste');
    await robot.tap(CalendarKeys.delete);

    expect(find.byKey(CalendarKeys.scopeSeries), findsNothing);
    expect(calendar.items, isEmpty);
  });

  testWidgets('the schedule view lists upcoming events', (tester) async {
    // Aujourd'hui plutôt que le mardi de la semaine : la vue planning va
    // par mois, et ce mardi peut tomber le mois précédent.
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12).toUtc();
    final calendar = FakeCalendarRepository()
      ..seed(
        AgendaItem(
          eventId: 'evt-dentist',
          calendarId: FakeCalendarRepository.calendarId,
          title: 'Dentiste',
          start: noon,
          end: noon.add(const Duration(hours: 1)),
          isAllDay: false,
          timezone: 'Europe/Paris',
        ),
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.tap(CalendarKeys.viewSchedule);

    expect(find.text('Dentiste'), findsWidgets);
  });

  testWidgets('the agenda speaks English on an English device', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), locale: const Locale('en'));

    expect(find.text('Week'), findsOneWidget);
    expect(find.byTooltip('New event'), findsOneWidget);
  });

  testWidgets('the agenda refreshes after an action even without realtime', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository()..realtimeEnabled = false;
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);
    calendar.calls.clear();

    await robot.openNewEvent();
    await robot.enter(CalendarKeys.title, 'Piscine');
    await robot.tap(CalendarKeys.save);

    // Sans temps réel, seule l'invalidation après l'action relit l'agenda.
    expect(calendar.calls, ['createEvent', 'fetchAgenda']);
  });

  testWidgets('a deleted event disappears from the grid without realtime', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository()
      ..realtimeEnabled = false
      ..seed(_dentist());
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);
    expect(find.text('Dentiste'), findsWidgets);

    await robot.tapEvent('Dentiste');
    await robot.tap(CalendarKeys.delete);

    expect(find.text('Dentiste'), findsNothing);
  });
}
