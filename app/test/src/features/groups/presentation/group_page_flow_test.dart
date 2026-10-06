import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fake_calendars_repository.dart';
import '../../../../helpers/fake_groups_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

FakeGroupsRepository _coloc() =>
    FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc');

/// Répond au presse-papiers comme s'il contenait [text].
void _clipboardHolds(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData' ? {'text': text} : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('the group page offers sharing and slots, not four icons', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: _coloc());

    await robot.openGroup('g-coloc');

    expect(find.byKey(GroupKeys.myShareChip), findsOneWidget);
    expect(find.byKey(GroupKeys.findSlots), findsOneWidget);
    robot.expectText('Trouver un créneau');
    // Inviter se fait depuis les membres.
    expect(find.byKey(GroupKeys.invite), findsNothing);
    await robot.tap(GroupKeys.members);
    expect(find.byKey(GroupKeys.invite), findsOneWidget);
  });

  testWidgets('an invite is shared through the phone share sheet', (
    tester,
  ) async {
    final groups = _coloc()
      ..seedInvite('WXYZ2345', 'g-coloc', createdBy: FakeGroupsRepository.me);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: groups,
      webBaseUrl: Uri.parse('https://agora.example'),
    );

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.members);
    await robot.tap(GroupKeys.invite);
    await robot.tap(GroupKeys.shareInvite);

    expect(robot.sharer.shared, [
      'Rejoins « Coloc » sur Agora : https://agora.example/#/join/WXYZ2345',
    ]);
  });

  testWidgets('without a web address, the code itself is shared', (
    tester,
  ) async {
    final groups = _coloc()
      ..seedInvite('WXYZ2345', 'g-coloc', createdBy: FakeGroupsRepository.me);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.members);
    await robot.tap(GroupKeys.invite);
    await robot.tap(GroupKeys.shareInvite);

    expect(robot.sharer.shared, [
      'Rejoins « Coloc » sur Agora avec le code WXYZ2345',
    ]);
  });

  testWidgets('without a share sheet (web), only copying is offered', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _coloc(),
      sharer: FakeSharer(isAvailable: false),
    );

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.members);
    await robot.tap(GroupKeys.invite);

    expect(find.byKey(GroupKeys.shareInvite), findsNothing);
    expect(find.byKey(GroupKeys.copyCode), findsOneWidget);
  });

  testWidgets('pasting a received link keeps only its code', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());
    _clipboardHolds(
      tester,
      'Rejoins « Coloc » sur Agora : https://agora.example/#/join/abcd2345',
    );

    await robot.openSocialTab();
    await robot.addFromSocial(GroupKeys.joinWithCode);
    await robot.tap(GroupKeys.pasteCode);

    expect(
      tester
          .widget<TextField>(find.byKey(GroupKeys.codeField))
          .controller!
          .text,
      'ABCD2345',
    );
  });

  testWidgets('a code typed in lowercase shows in capitals', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openSocialTab();
    await robot.addFromSocial(GroupKeys.joinWithCode);
    await robot.enter(GroupKeys.codeField, 'abcd2345');

    expect(find.text('ABCD2345'), findsOneWidget);
  });

  testWidgets("Social shows a group's next event", (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day + 2, 20).toUtc();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _coloc(),
      calendars: FakeCalendarsRepository([
        const UserCalendar(
          id: FakeCalendarRepository.calendarId,
          name: 'Agenda',
          kind: CalendarKind.native,
        ),
        const UserCalendar(
          id: 'cal-coloc',
          name: 'Coloc',
          kind: CalendarKind.native,
          groupId: 'g-coloc',
        ),
      ]),
      calendar: FakeCalendarRepository()
        ..seed(
          AgendaItem(
            eventId: 'evt-raclette',
            calendarId: 'cal-coloc',
            title: 'Raclette',
            start: start,
            end: start.add(const Duration(hours: 3)),
            isAllDay: false,
            timezone: 'Europe/Paris',
          ),
        ),
    );

    await robot.openSocialTab();

    expect(find.textContaining('Prochain : Raclette'), findsOneWidget);
  });
}
