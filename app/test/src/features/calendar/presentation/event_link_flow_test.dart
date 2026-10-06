import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/groups/domain/group.dart';
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

/// Un parcours d'Arpente : samedi 10 octobre, 14 h à Paris, 2 h 30.
String _link({String? group}) => Uri(
  path: '/event',
  queryParameters: {
    'de': 'arpente',
    'titre': 'Sortie Caen — Caen',
    'debut': '2026-10-10T14:00:00+02:00',
    'duree': '150',
    'lieu': 'Château de Caen',
    'description': 'Parcours de 2 lieux.\n\n1. Château\n2. Abbaye',
    'groupe': ?group,
  },
).toString();

FakeCalendarsRepository _withGroupCalendar() => FakeCalendarsRepository([
  const UserCalendar(
    id: FakeCalendarRepository.calendarId,
    name: 'Agenda',
    kind: CalendarKind.native,
  ),
  const UserCalendar(
    id: 'cal-g1',
    name: 'Coloc',
    kind: CalendarKind.native,
    groupId: 'g-1',
  ),
]);

String _fieldText(WidgetTester tester, Key key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    )
    .controller
    .text;

void main() {
  testWidgets('a parcours from Arpente opens a prefilled rdv', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openLink(_link());

    robot.expectText(
      "Préparé dans Arpente : vérifie le rdv avant de l'enregistrer.",
    );
    expect(_fieldText(tester, CalendarKeys.title), 'Sortie Caen — Caen');
    expect(_fieldText(tester, CalendarKeys.location), 'Château de Caen');
    expect(
      _fieldText(tester, CalendarKeys.description),
      'Parcours de 2 lieux.\n\n1. Château\n2. Abbaye',
    );

    await robot.tap(CalendarKeys.save);

    final saved = robot.calendar.items.single;
    expect(saved.calendarId, FakeCalendarRepository.calendarId);
    expect(saved.title, 'Sortie Caen — Caen');
    expect(saved.start, DateTime.utc(2026, 10, 10, 12));
    expect(saved.end, DateTime.utc(2026, 10, 10, 14, 30));
    expect(saved.location, 'Château de Caen');
  });

  testWidgets('a member finds the twin group already chosen', (tester) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-1', 'Coloc')
      ..seedInvite('WXYZ2345', 'g-1');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: groups,
      calendars: _withGroupCalendar(),
    );

    await robot.openLink(_link(group: 'WXYZ2345'));
    await robot.tap(CalendarKeys.save);

    expect(robot.calendar.items.single.calendarId, 'cal-g1');
  });

  testWidgets('the rdv can still go to my own agenda', (tester) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-1', 'Coloc')
      ..seedInvite('WXYZ2345', 'g-1');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: groups,
      calendars: _withGroupCalendar(),
    );

    await robot.openLink(_link(group: 'WXYZ2345'));
    await robot.tap(CalendarKeys.eventCalendar);
    await tester.tap(
      find
          .byKey(
            CalendarKeys.eventCalendarOption(FakeCalendarRepository.calendarId),
          )
          .last,
    );
    await robot.settle();
    await robot.tap(CalendarKeys.save);

    expect(
      robot.calendar.items.single.calendarId,
      FakeCalendarRepository.calendarId,
    );
  });

  testWidgets('not yet in the twin group: offered to join it first', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()
      ..groups['g-2'] = FakeGroup(
        'g-2',
        'Club',
        members: [FakeMember('other', 'Max', GroupRole.owner, ShareLevel.busy)],
      )
      ..seedInvite('WXYZ2345', 'g-2');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openLink(_link(group: 'WXYZ2345'));

    robot.expectText(
      "Tu n'es pas encore dans le groupe « Club » : rejoins-le, puis rouvre "
      'le lien depuis Arpente pour lui proposer le rdv.',
    );
    await robot.tap(CalendarKeys.eventLinkJoin);
    robot.expectScreen(GroupKeys.joinScreen);
  });

  testWidgets('only my own agendas and my groups are offered', (tester) async {
    final calendars = _withGroupCalendar()
      ..pushFromServer(
        const UserCalendar(
          id: 'cal-mom',
          name: 'Maman',
          kind: CalendarKind.native,
          isContact: true,
        ),
      )
      ..pushFromServer(
        const UserCalendar(
          id: 'cal-ics',
          name: 'Boulot',
          kind: CalendarKind.ics,
        ),
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: calendars);

    await robot.openLink(_link());
    await robot.tap(CalendarKeys.eventCalendar);

    expect(
      find.byKey(CalendarKeys.eventCalendarOption('cal-g1')),
      findsWidgets,
    );
    expect(
      find.byKey(CalendarKeys.eventCalendarOption('cal-mom')),
      findsNothing,
    );
    expect(
      find.byKey(CalendarKeys.eventCalendarOption('cal-ics')),
      findsNothing,
    );
  });

  testWidgets('a change to my agendas keeps what I typed', (tester) async {
    final calendars = _withGroupCalendar();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: calendars);

    await robot.openLink(_link());
    await tester.enterText(
      find.descendant(
        of: find.byKey(CalendarKeys.title),
        matching: find.byType(EditableText),
      ),
      'Visite du château',
    );
    // Un autre appareil renomme un agenda : le temps réel relit la liste,
    // le temps d'un aller-retour réseau.
    calendars
      ..fetchLatency = const Duration(milliseconds: 300)
      ..pushFromServer(
        const UserCalendar(
          id: 'cal-g1',
          name: 'Coloc du 3e',
          kind: CalendarKind.native,
          groupId: 'g-1',
        ),
      );
    await robot.settle();

    expect(_fieldText(tester, CalendarKeys.title), 'Visite du château');
    // La liste a bien été relue : le nouveau nom est proposé.
    await robot.tap(CalendarKeys.eventCalendar);
    expect(find.text('Coloc du 3e'), findsWidgets);
  });

  testWidgets('opened signed out, comes back after sign-in', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();

    // Tel qu'Android le transmet : la racine, et le fragment du web.
    await robot.openLink('/#${_link()}');
    await robot.signIn('zoe@test.local', 'motdepasse');

    expect(_fieldText(tester, CalendarKeys.title), 'Sortie Caen — Caen');
  });

  testWidgets('a malformed link is refused', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openLink(
      '/event?de=arpente&titre=Sortie&debut=2026-10-10T14:00:00&duree=150',
    );

    robot.expectText(
      "Ce lien de rdv n'est pas valable. Rouvre-le depuis l'app qui l'a "
      'préparé.',
    );
    expect(find.byKey(CalendarKeys.save), findsNothing);
  });
}
