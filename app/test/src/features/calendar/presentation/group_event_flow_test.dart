import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
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

const _me = FakeAuthRepository.userId;
const _groupId = 'g-foot';
const _personal = UserCalendar(
  id: FakeCalendarRepository.calendarId,
  name: 'Agenda',
  kind: CalendarKind.native,
);
// L'agenda d'un groupe garde le nom du groupe à sa création.
const _groupCalendar = UserCalendar(
  id: 'cal-foot',
  name: 'Ancien nom',
  kind: CalendarKind.native,
  groupId: _groupId,
);

/// Mardi de la semaine affichée par défaut (elle commence le lundi), à
/// [hour] h locales : visible quel que soit le jour du test.
DateTime _tuesdayThisWeekAt(int hour) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + 1, hour).toUtc();
}

AgendaItem _match({ResponseStatus? myResponse}) {
  final start = _tuesdayThisWeekAt(18);
  return AgendaItem(
    eventId: 'evt-match',
    calendarId: _groupCalendar.id,
    title: 'Match',
    location: 'Stade',
    start: start,
    end: start.add(const Duration(hours: 2)),
    isAllDay: false,
    timezone: 'Europe/Paris',
    myResponse: myResponse,
  );
}

/// Un groupe « Foot » : Léa le possède, l'utilisateur en est [myRole].
FakeGroupsRepository _foot({GroupRole myRole = GroupRole.member}) {
  final groups = FakeGroupsRepository();
  final foot = groups.seedGroup(
    _groupId,
    'Foot',
    myRole: myRole,
    others: [
      FakeMember('u-lea', 'Léa', GroupRole.owner, ShareLevel.details),
      FakeMember('u-max', 'Max', GroupRole.member, ShareLevel.busy),
    ],
  );
  final match = _match();
  foot.agenda.add(
    GroupAgendaItem(
      eventId: match.eventId,
      isGroupEvent: true,
      level: ShareLevel.details,
      title: match.title,
      location: match.location,
      start: match.start,
      end: match.end,
      isAllDay: false,
    ),
  );
  return groups;
}

/// Le match, proposé par [createdBy].
FakeCalendarRepository _calendarWithMatch({
  String createdBy = 'u-lea',
  ResponseStatus? myResponse,
}) {
  final calendar = FakeCalendarRepository()
    ..seed(_match(myResponse: myResponse));
  calendar.creators['evt-match'] = createdBy;
  return calendar;
}

Future<AgoraRobot> _pump(
  WidgetTester tester, {
  FakeGroupsRepository? groups,
  FakeCalendarRepository? calendar,
}) async {
  final robot = AgoraRobot(tester);
  await robot.pumpApp(
    auth: _signedIn(),
    groups: groups ?? _foot(),
    calendar: calendar ?? _calendarWithMatch(),
    calendars: FakeCalendarsRepository([_personal, _groupCalendar]),
  );
  return robot;
}

Finder _inSection(Key section, String text) => find.descendant(
  of: find.byKey(section),
  matching: find.textContaining(text),
);

void main() {
  testWidgets('a member answers a group event from the group agenda', (
    tester,
  ) async {
    final robot = await _pump(tester);

    await robot.openGroup(_groupId);
    await robot.tapEvent('Match');

    robot.expectScreen(CalendarKeys.groupEventScreen);
    robot.expectText('Proposé par Léa');
    expect(find.byKey(CalendarKeys.groupEventEdit), findsNothing);
    expect(_inSection(CalendarKeys.noResponseSection, 'Vous'), findsOne);

    await robot.tap(CalendarKeys.responseOption(ResponseStatus.yes));

    expect(robot.calendar.responses[ResponseKey('evt-match')], {
      _me: ResponseStatus.yes,
    });
    robot.expectText('Réponse enregistrée.');
    expect(
      _inSection(CalendarKeys.responseSection(ResponseStatus.yes), 'Vous'),
      findsOne,
    );
    expect(_inSection(CalendarKeys.noResponseSection, 'Léa, Max'), findsOne);
  });

  testWidgets('choosing my answer again takes it back', (tester) async {
    final robot = await _pump(tester);

    await robot.openGroup(_groupId);
    await robot.tapEvent('Match');
    await robot.tap(CalendarKeys.responseOption(ResponseStatus.maybe));
    await robot.tap(CalendarKeys.responseOption(ResponseStatus.maybe));

    expect(robot.calendar.responses[ResponseKey('evt-match')], isEmpty);
    robot.expectText('Réponse retirée.');
  });

  testWidgets('its creator can delete a group event', (tester) async {
    final robot = await _pump(
      tester,
      calendar: _calendarWithMatch(createdBy: _me),
    );

    await robot.openGroup(_groupId);
    await robot.tapEvent('Match');
    await robot.tap(CalendarKeys.groupEventDelete);

    expect(robot.calendar.writes, contains('deleteEvent'));
    expect(robot.calendar.items, isEmpty);
    robot.expectScreen(GroupKeys.groupScreen);
    robot.expectText('Rendez-vous supprimé.');
  });

  testWidgets('a group admin can edit any group event', (tester) async {
    final robot = await _pump(tester, groups: _foot(myRole: GroupRole.admin));

    await robot.openGroup(_groupId);
    await robot.tapEvent('Match');
    await robot.tap(CalendarKeys.groupEventEdit);
    await robot.enter(CalendarKeys.title, 'Match retour');
    await robot.tap(CalendarKeys.save);

    expect(robot.calendar.items.single.title, 'Match retour');
    robot.expectScreen(GroupKeys.groupScreen);
  });

  testWidgets('proposing an event files it in the group calendar', (
    tester,
  ) async {
    final robot = await _pump(tester, calendar: FakeCalendarRepository());

    await robot.openGroup(_groupId);
    await robot.tap(GroupKeys.proposeEvent);

    robot.expectScreen(CalendarKeys.editor);
    expect(
      find.byKey(CalendarKeys.visibility),
      findsNothing,
      reason: 'a group event is seen in full by every member',
    );
    await robot.enter(CalendarKeys.title, 'Apéro');
    await robot.tap(CalendarKeys.save);

    final created = robot.calendar.items.single;
    expect(created.title, 'Apéro');
    expect(created.calendarId, _groupCalendar.id);
    expect(created.visibility, isNull);
    robot.expectScreen(GroupKeys.groupScreen);
    robot.expectText('Rendez-vous proposé au groupe.');
  });

  testWidgets('a group event in my agenda opens its card, not the editor', (
    tester,
  ) async {
    final robot = await _pump(tester);

    await robot.tapEvent('Match');

    robot.expectScreen(CalendarKeys.groupEventScreen);
    expect(find.byKey(CalendarKeys.editor), findsNothing);
  });

  testWidgets('a group event I declined stays in my agenda, struck through', (
    tester,
  ) async {
    await _pump(
      tester,
      calendar: _calendarWithMatch(myResponse: ResponseStatus.no),
    );

    final title = tester.widget<Text>(find.text('Match').first);
    expect(title.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('a series is answered occurrence by occurrence', (tester) async {
    final first = _tuesdayThisWeekAt(10);
    final calendar = FakeCalendarRepository();
    for (final start in [first, first.add(const Duration(days: 7))]) {
      calendar.seed(
        AgendaItem(
          eventId: 'evt-training',
          seriesId: 'evt-training',
          originalStart: start,
          calendarId: _groupCalendar.id,
          title: 'Entraînement',
          start: start,
          end: start.add(const Duration(hours: 1)),
          isAllDay: false,
          timezone: 'Europe/Paris',
          rrule: 'FREQ=WEEKLY',
        ),
      );
    }
    final robot = await _pump(tester, calendar: calendar);

    await robot.tapEvent('Entraînement');
    robot.expectText(
      'Rendez-vous répété : votre réponse vaut pour cette date.',
    );
    await robot.tap(CalendarKeys.responseOption(ResponseStatus.no));

    expect(calendar.responses.keys.single, ResponseKey('evt-training', first));
  });

  testWidgets('my calendars list my groups under their current name', (
    tester,
  ) async {
    final robot = await _pump(tester);

    await robot.openCalendars();

    robot.expectScreen(CalendarKeys.groupCalendarsHeader);
    robot.expectText('Foot');
    expect(find.text('Ancien nom'), findsNothing);
    await robot.tap(CalendarKeys.calendarShown(_groupCalendar.id));

    expect(robot.calendars.calendars.last.hidden, isTrue);
  });
}
