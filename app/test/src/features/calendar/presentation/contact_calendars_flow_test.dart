import 'package:agora/src/features/auth/domain/app_user.dart';
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

void main() {
  testWidgets('adding a close one creates a calendar kept to myself', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    await robot.tap(CalendarKeys.newContactCalendar);
    await robot.enter(CalendarKeys.calendarName, 'Léa');
    // Pas de réglage de partage : l'agenda d'un proche n'est qu'à moi.
    expect(find.byKey(CalendarKeys.calendarVisibility), findsNothing);
    robot.expectText(
      'Visible de toi seul : ses repos et son anniversaire ne comptent '
      'jamais comme tes créneaux pris.',
    );
    await robot.tap(CalendarKeys.calendarSave);

    final created = robot.calendars.calendars.last;
    expect(created.name, 'Léa');
    expect(created.isContact, isTrue);
    expect(created.visibility, EventVisibility.invisible);
    expect(find.byKey(CalendarKeys.contactCalendarsHeader), findsOneWidget);
    robot.expectText('Proche ajouté.');
  });

  testWidgets("a close one's calendar never counts as my only calendar", (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _lea]),
    );

    await robot.openCalendars();
    await robot.tap(CalendarKeys.calendarTile(_personal.id));
    expect(find.byKey(CalendarKeys.calendarDelete), findsNothing);
    // L'éditeur s'ouvre en plein écran : il se ferme par sa croix.
    await tester.tap(find.byType(CloseButton));
    await robot.settle();

    await robot.tap(CalendarKeys.calendarTile(_lea.id));
    expect(find.byKey(CalendarKeys.calendarDelete), findsOneWidget);
    expect(find.byKey(CalendarKeys.calendarVisibility), findsNothing);
  });

  testWidgets("importing a close one's schedule by its iCal link", (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    await robot.tap(CalendarKeys.importCalendar);
    await robot.enter(CalendarKeys.importUrl, 'https://exemple.test/lea.ics');
    await robot.enter(CalendarKeys.importName, 'Planning de Léa');
    await robot.tap(CalendarKeys.importForContact);
    await robot.tap(CalendarKeys.importSave);

    final imported = robot.calendars.calendars.last;
    expect(imported.isImported, isTrue);
    expect(imported.isContact, isTrue);
  });
}
