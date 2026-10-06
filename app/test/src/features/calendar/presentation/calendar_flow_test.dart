import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

/// Aujourd'hui à 18 h locales : visible dans la vue par défaut quel que soit
/// le jour du test, la semaine complète (écran large) comme les trois jours
/// glissants qui commencent aujourd'hui (écran étroit).
DateTime _today18h() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 18).toUtc();
}

/// Écran assez large pour la semaine complète, commencée le lundi.
const _wideScreen = Size(1280, 800);

AgendaItem _dentist() {
  final start = _today18h();
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
  final start = _today18h();
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

    await robot.editEvent('Yoga');
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
    final day = _today18h().toLocal();
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

    await robot.editEvent('Congé');
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

  testWidgets('on a phone, the week view starts today, whatever the weekday', (
    tester,
  ) async {
    // Sur un écran étroit, la semaine se réduit à trois jours. Réduite par
    // kalender.week, elle montrait toujours lundi–mercredi : un rdv de jeudi
    // à dimanche n'y apparaissait jamais. Elle doit partir d'aujourd'hui.
    final now = DateTime.now();
    final inTwoDays = DateTime(now.year, now.month, now.day + 2, 12).toUtc();
    final calendar = FakeCalendarRepository()
      ..seed(
        AgendaItem(
          eventId: 'evt-later',
          calendarId: FakeCalendarRepository.calendarId,
          title: 'Kiné',
          start: inTwoDays,
          end: inTwoDays.add(const Duration(hours: 1)),
          isAllDay: false,
          timezone: 'Europe/Paris',
        ),
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: calendar,
      screenSize: const Size(390, 844),
    );

    expect(find.text('Kiné'), findsWidgets);
  });

  testWidgets('the month view opens on the current month, even early in it', (
    tester,
  ) async {
    // Depuis la semaine complète, kalender ouvrait le mois de son LUNDI : un
    // 1er octobre, la semaine commence le 28 septembre, et le mois affiché
    // était septembre. Le défaut n'apparaît qu'en début de mois ; le reste du
    // temps, ce test passe de lui-même.
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), screenSize: _wideScreen);

    await robot.chooseView(CalendarKeys.toolbar, AgendaView.month);

    final now = DateTime.now();
    final visible = tester
        .widget<KalenderView>(find.byType(KalenderView))
        .kalenderController
        .visibleDateTimeRange
        .value!;
    expect(visible.start.isAfter(DateTime(now.year, now.month)), isFalse);
    expect(visible.end.isBefore(DateTime(now.year, now.month + 1)), isFalse);
  });

  testWidgets('the schedule view lists upcoming events', (tester) async {
    // Écran large : la semaine complète commence le lundi, qui peut tomber
    // le mois précédent ; le planning, paginé par mois, doit pourtant
    // s'ouvrir sur celui d'aujourd'hui.
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
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: calendar,
      screenSize: _wideScreen,
    );

    await robot.chooseView(CalendarKeys.toolbar, AgendaView.schedule);

    expect(find.text('Dentiste'), findsWidgets);
  });

  testWidgets('the agenda speaks English on an English device', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), locale: const Locale('en'));

    expect(find.byTooltip('Change view'), findsOneWidget);
    expect(find.byTooltip('New event'), findsOneWidget);
    await robot.tap(CalendarKeys.toolbar.viewMenu);
    // Sur un téléphone, la « semaine » n'a que trois jours, et le dit.
    expect(find.text('3 days'), findsOneWidget);
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
