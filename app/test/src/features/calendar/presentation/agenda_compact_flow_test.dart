import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
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

const _phone = Size(412, 915);

const _personal = UserCalendar(
  id: FakeCalendarRepository.calendarId,
  name: 'Agenda',
  kind: CalendarKind.native,
);
const _lea = UserCalendar(
  id: 'cal-lea',
  name: 'Léa',
  kind: CalendarKind.native,
  visibility: EventVisibility.invisible,
  isContact: true,
);
const _leaPlanning = UserCalendar(
  id: 'cal-lea-ics',
  name: 'Planning de Léa',
  kind: CalendarKind.ics,
  visibility: EventVisibility.invisible,
  isContact: true,
);

/// Aujourd'hui à [hour] h locales.
DateTime _todayAt(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour).toUtc();
}

AgendaItem _event(
  String title, {
  String calendarId = FakeCalendarRepository.calendarId,
  String? location,
}) {
  final start = _todayAt(18);
  return AgendaItem(
    eventId: 'evt-$title',
    calendarId: calendarId,
    title: title,
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'Europe/Paris',
    location: location,
  );
}

void main() {
  testWidgets('a tap on my event opens its sheet, not the editor', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()
        ..seed(_event('Dentiste', location: '3 place Royale')),
    );

    await robot.tapEvent('Dentiste');

    robot.expectScreen(CalendarKeys.eventSheet);
    expect(find.byKey(CalendarKeys.editor), findsNothing);
    robot.expectText('3 place Royale');
    await robot.tap(CalendarKeys.eventEdit);
    robot.expectScreen(CalendarKeys.editor);
  });

  testWidgets("a close one's imported schedule reads only", (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _leaPlanning]),
      calendar: FakeCalendarRepository()
        ..seed(_event('Service', calendarId: _leaPlanning.id)),
    );

    await robot.tapEvent('Service');

    robot.expectScreen(CalendarKeys.eventSheet);
    robot.expectText('Pour toi seul');
    expect(find.byKey(CalendarKeys.eventEdit), findsNothing);
    expect(find.byKey(CalendarKeys.delete), findsNothing);
  });

  testWidgets("a close one's event wears a small figure", (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _lea]),
      calendar: FakeCalendarRepository()
        ..seed(_event('Repos de Léa', calendarId: _lea.id)),
    );

    expect(find.text('Repos de Léa'), findsWidgets);
    expect(find.byIcon(Icons.person_outline), findsWidgets);
  });

  testWidgets('on a phone, the toolbar is one line with a view menu', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), screenSize: _phone);

    expect(find.byKey(CalendarKeys.toolbar.viewMenu), findsOneWidget);
    expect(find.byType(SegmentedButton<AgendaView>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone, the month lists the day, and a tap picks a day', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      screenSize: _phone,
      calendar: FakeCalendarRepository()..seed(_event('Piscine')),
    );

    await robot.chooseView(CalendarKeys.toolbar, AgendaView.month);

    expect(find.byKey(CalendarKeys.monthDayList), findsOneWidget);
    // Les jours de la semaine s'abrègent : leurs noms entiers étaient coupés.
    expect(find.text('dim.'), findsOneWidget);
    expect(find.text('dimanche'), findsNothing);
    expect(
      find.byKey(CalendarKeys.monthDayItem(_event('Piscine').instanceKey)),
      findsOneWidget,
    );
    await robot.tap(CalendarKeys.monthDayItem(_event('Piscine').instanceKey));
    robot.expectScreen(CalendarKeys.eventSheet);
    await robot.dismissSheet();
    // Un appui sur un jour le choisit : aucun éditeur ne s'ouvre.
    final today = DateTime.now();
    final other = today.day == 15 ? '16' : '15';
    // Sous le numéro du jour, dans sa case : le numéro n'est qu'un libellé.
    await tester.tapAt(
      tester.getCenter(find.text(other).first) + const Offset(0, 30),
    );
    await robot.settle();
    expect(find.byKey(CalendarKeys.editor), findsNothing);
    robot.expectText('Rien de noté ce jour-là.');
  });

  testWidgets('shown calendars cover mine, my close ones and my groups', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _lea]),
    );

    await robot.openShownCalendars();

    expect(find.byKey(CalendarKeys.calendarShown(_personal.id)), findsOne);
    expect(find.byKey(CalendarKeys.calendarShown(_lea.id)), findsOne);
    await robot.tap(CalendarKeys.calendarShown(_lea.id));
    expect(robot.calendars.calendars.last.hidden, isTrue);
  });
}
