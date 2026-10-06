import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/agora_robot.dart';
import '../../../helpers/fake_calendar_repository.dart';
import '../../../helpers/fake_calendars_repository.dart';
import '../../../helpers/fake_groups_repository.dart';
import '../../../helpers/fakes.dart';

/// Un petit téléphone (360 × 740) : un débordement y lève une erreur de mise
/// en page, que le test voit. Les parcours ordinaires tournent sur une
/// surface de 800 px, qui ne les montre pas.
const _smallPhone = Size(360, 740);

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'camille.longue-adresse@exemple.test',
  ),
);

const _peushu = UserCalendar(
  id: 'cal-peushu',
  name: 'Peushu',
  kind: CalendarKind.native,
  visibility: EventVisibility.invisible,
  isContact: true,
);

void main() {
  testWidgets('Social, a close one and the repeat editor fit a phone', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      screenSize: _smallPhone,
      calendars: FakeCalendarsRepository([
        const UserCalendar(
          id: FakeCalendarRepository.calendarId,
          name: 'Agenda',
          kind: CalendarKind.native,
        ),
        _peushu,
      ]),
      groups: FakeGroupsRepository()
        ..seedGroup('g-1', 'Les amis du jeudi soir au bar du coin'),
    );

    await robot.openSocialTab();
    expect(find.byKey(GroupKeys.groupTile('g-1')), findsOneWidget);
    // La page d'un groupe : puces, barre d'agenda d'une ligne.
    await robot.tap(GroupKeys.groupTile('g-1'));
    expect(find.byKey(GroupKeys.myShareChip), findsOneWidget);
    expect(tester.takeException(), isNull);
    await robot.goBack();
    await robot.tap(CalendarKeys.contactTile(_peushu.id));
    await robot.tap(CalendarKeys.contactWorkHours);
    await robot.chooseRepeat(Frequency.weekly);
    expect(find.byKey(CalendarKeys.repeatInterval), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Moi tab and the assistant screen fit a phone', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      screenSize: _smallPhone,
      deviceTimezone: 'America/Argentina/Buenos_Aires',
      mcpUrl: Uri.parse('https://api.agora.test/mcp'),
      webBaseUrl: Uri.parse('https://agora.test'),
    );

    await robot.openProfile();
    expect(find.byKey(ProfileKeys.useDeviceTimezone), findsOneWidget);
    await robot.tap(ProfileKeys.assistant);
    expect(tester.takeException(), isNull);
  });
}
