import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:flutter/material.dart';
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

const _personal = UserCalendar(
  id: FakeCalendarRepository.calendarId,
  name: 'Agenda',
  kind: CalendarKind.native,
);
const _leaLinked = UserCalendar(
  id: 'cal-lea',
  name: 'Léa',
  kind: CalendarKind.native,
  visibility: EventVisibility.invisible,
  isContact: true,
  contactUserId: 'u-lea',
);
const _tonton = UserCalendar(
  id: 'cal-tonton',
  name: 'Tonton',
  kind: CalendarKind.native,
  visibility: EventVisibility.invisible,
  isContact: true,
);

FakeGroupsRepository _famille() => FakeGroupsRepository()
  ..seedGroup(
    'g-famille',
    'Famille',
    myRole: GroupRole.member,
    others: [
      FakeMember('u-lea', 'Léa', GroupRole.owner, ShareLevel.details),
      FakeMember('u-dan', 'Dan', GroupRole.member, ShareLevel.busy),
    ],
  );

FakeCalendarsRepository _calendars(List<UserCalendar> calendars) =>
    FakeCalendarsRepository([_personal, ...calendars])
      ..coMembers.addAll({'u-lea': 'Léa', 'u-dan': 'Dan'});

void main() {
  testWidgets('a group member joins my close ones from the members list', (
    tester,
  ) async {
    final calendars = _calendars(const []);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _famille(),
      calendars: calendars,
    );

    await robot.openGroup('g-famille');
    await robot.tap(GroupKeys.members);
    // Un simple membre n'a pas de menu de rôles, mais peut ajouter un proche.
    expect(find.byKey(GroupKeys.memberMenu('u-dan')), findsNothing);
    await robot.tap(GroupKeys.memberContact('u-dan'));

    robot.expectScreen(CalendarKeys.contactScreen);
    final created = calendars.calendars.last;
    expect(created.isContact, isTrue);
    expect(created.contactUserId, 'u-dan');
    expect(created.name, 'Dan');
    expect(find.byKey(CalendarKeys.contactUnlink), findsOneWidget);
  });

  testWidgets('a member already among my close ones opens their page', (
    tester,
  ) async {
    final calendars = _calendars(const [_leaLinked]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _famille(),
      calendars: calendars,
    );

    await robot.openGroup('g-famille');
    await robot.tap(GroupKeys.members);
    expect(find.textContaining('dans tes proches'), findsOneWidget);
    await robot.tap(GroupKeys.memberContact('u-lea'));

    robot.expectScreen(CalendarKeys.contactScreen);
    expect(calendars.calls, isNot(contains('createMemberContact')));
  });

  testWidgets('an existing close one is linked to a member, then unlinked', (
    tester,
  ) async {
    final calendars = _calendars(const [_leaLinked, _tonton]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _famille(),
      calendars: calendars,
    );

    await robot.openContact(_tonton.id);
    await robot.scrollTo(CalendarKeys.contactLink);
    await robot.tap(CalendarKeys.contactLink);
    // Léa est déjà le proche « Léa » : on ne la propose pas une seconde fois.
    expect(find.byKey(CalendarKeys.contactLinkOption('u-lea')), findsNothing);
    await robot.tap(CalendarKeys.contactLinkOption('u-dan'));

    UserCalendar tonton() =>
        calendars.calendars.firstWhere((c) => c.id == _tonton.id);
    expect(tonton().contactUserId, 'u-dan');
    expect(tonton().name, 'Dan');

    await robot.scrollTo(CalendarKeys.contactUnlink);
    await robot.tap(CalendarKeys.contactUnlink);
    expect(tonton().contactUserId, isNull);
    expect(find.byKey(CalendarKeys.contactLink), findsOneWidget);
  });

  testWidgets('a linked close one shows what they share in our groups', (
    tester,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 10).toUtc();
    final groups = _famille();
    groups.groups['g-famille']!.agenda.addAll([
      GroupAgendaItem(
        level: ShareLevel.details,
        eventId: 'evt-piscine',
        userId: 'u-lea',
        title: 'Piscine',
        start: tomorrow,
        end: tomorrow.add(const Duration(hours: 1)),
        isAllDay: false,
      ),
      GroupAgendaItem(
        level: ShareLevel.busy,
        userId: 'u-dan',
        start: tomorrow,
        end: tomorrow.add(const Duration(hours: 2)),
        isAllDay: false,
      ),
    ]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: groups,
      calendars: _calendars(const [_leaLinked]),
    );

    await robot.openContact(_leaLinked.id);
    await robot.scrollTo(CalendarKeys.contactShared);

    expect(find.text('Piscine'), findsOneWidget);
    // Les créneaux de Dan restent ceux de Dan.
    expect(find.text('Occupé'), findsNothing);
  });

  testWidgets("a linked close one's name follows their profile", (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _famille(),
      calendars: _calendars(const [_leaLinked]),
    );

    await robot.openContact(_leaLinked.id);
    await robot.tap(CalendarKeys.contactEdit);

    final name = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(CalendarKeys.calendarName),
        matching: find.byType(TextField),
      ),
    );
    expect(name.enabled, isFalse);
    robot.expectText('Son nom suit celui de son profil Agora.');
  });

  testWidgets('a member who left our groups cannot be added', (tester) async {
    final calendars = _calendars(const []);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _famille(),
      calendars: calendars,
    );
    await robot.openGroup('g-famille');
    await robot.tap(GroupKeys.members);

    calendars.nextError = const NotCoMemberException();
    await robot.tap(GroupKeys.memberContact('u-dan'));

    robot.expectText('Cette personne ne partage plus de groupe avec toi.');
    expect(find.byKey(CalendarKeys.contactScreen), findsNothing);
  });
}
