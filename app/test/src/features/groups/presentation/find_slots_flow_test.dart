import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
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

const _groupId = 'g-foot';
const _groupCalendar = UserCalendar(
  id: 'cal-foot',
  name: 'Foot',
  kind: CalendarKind.native,
  groupId: _groupId,
);

/// Foot : Léa partage le détail, Max ne partage rien.
FakeGroupsRepository _foot({bool leaBusyAllWeek = false}) {
  final groups = FakeGroupsRepository();
  final foot = groups.seedGroup(
    _groupId,
    'Foot',
    others: [
      FakeMember('u-lea', 'Léa', GroupRole.member, ShareLevel.details),
      FakeMember('u-max', 'Max', GroupRole.member, ShareLevel.invisible),
    ],
  );
  if (leaBusyAllWeek) {
    final now = DateTime.now();
    for (var day = 0; day < 8; day++) {
      final start = DateTime(now.year, now.month, now.day + day);
      foot.agenda.add(
        GroupAgendaItem(
          userId: 'u-lea',
          level: ShareLevel.busy,
          start: start.toUtc(),
          end: DateTime(start.year, start.month, start.day + 1).toUtc(),
          isAllDay: false,
        ),
      );
    }
  }
  return groups;
}

Future<AgoraRobot> _openSlots(
  WidgetTester tester, {
  FakeGroupsRepository? groups,
}) async {
  final robot = AgoraRobot(tester);
  await robot.pumpApp(
    auth: _signedIn(),
    groups: groups ?? _foot(),
    calendars: FakeCalendarsRepository([
      const UserCalendar(
        id: FakeCalendarRepository.calendarId,
        name: 'Agenda',
        kind: CalendarKind.native,
      ),
      _groupCalendar,
    ]),
  );
  await robot.openGroup(_groupId);
  await robot.tap(GroupKeys.findSlots);
  return robot;
}

void main() {
  testWidgets('common times list free slots and name who shares nothing', (
    tester,
  ) async {
    final robot = await _openSlots(tester);

    robot.expectScreen(GroupKeys.slotsScreen);
    await robot.scrollTo(GroupKeys.slotInvisibleNote);
    expect(
      find.textContaining('Max ne partage pas son agenda avec le groupe'),
      findsOne,
    );
    await robot.scrollTo(GroupKeys.slotTile(0));
    expect(find.byKey(GroupKeys.slotTile(0)), findsOne);
  });

  testWidgets('a member busy all week empties the list until left out', (
    tester,
  ) async {
    final robot = await _openSlots(tester, groups: _foot(leaBusyAllWeek: true));

    await robot.scrollTo(GroupKeys.slotsNone);
    robot.expectScreen(GroupKeys.slotsNone);
    await robot.tap(GroupKeys.slotMore);
    await robot.tap(GroupKeys.slotMember('u-lea'));

    expect(find.byKey(GroupKeys.slotsNone), findsNothing);
    await robot.scrollTo(GroupKeys.slotTile(0));
    expect(find.byKey(GroupKeys.slotTile(0)), findsOne);
  });

  testWidgets('proposing a free slot fills in the editor with its times', (
    tester,
  ) async {
    final robot = await _openSlots(tester);

    await robot.tap(GroupKeys.slotDuration(90));
    await robot.scrollTo(GroupKeys.slotTile(0));
    await robot.tap(GroupKeys.slotTile(0));
    robot.expectScreen(CalendarKeys.editor);
    await robot.enter(CalendarKeys.title, 'Réunion de bureau');
    await robot.tap(CalendarKeys.save);

    final created = robot.calendar.items.single;
    expect(created.calendarId, _groupCalendar.id);
    expect(created.end.difference(created.start), const Duration(minutes: 90));
    expect(created.start.minute % 15, 0);
    robot.expectScreen(GroupKeys.slotsScreen);
  });
}
