import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/home/presentation/social_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/agora_robot.dart';
import '../../../helpers/fake_calendar_repository.dart';
import '../../../helpers/fake_calendars_repository.dart';
import '../../../helpers/fake_groups_repository.dart';
import '../../../helpers/fakes.dart';

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
const _peushu = UserCalendar(
  id: 'cal-peushu',
  name: 'Peushu',
  kind: CalendarKind.native,
  visibility: EventVisibility.invisible,
  isContact: true,
);

FakeCalendarsRepository _withPeushu() =>
    FakeCalendarsRepository([_personal, _peushu]);

/// Dans [days] jours, journée entière (date de calendrier en minuit UTC).
AgendaItem _birthdayIn(int days) {
  final now = DateTime.now();
  final day = DateTime.utc(now.year, now.month, now.day + days);
  return AgendaItem(
    eventId: 'evt-birthday',
    seriesId: 'evt-birthday',
    originalStart: day,
    calendarId: _peushu.id,
    title: 'Anniversaire de Peushu',
    start: day,
    end: day.add(const Duration(days: 1)),
    isAllDay: true,
    timezone: 'Europe/Paris',
    rrule: 'FREQ=YEARLY',
  );
}

void main() {
  testWidgets('Social lists close ones and groups', (tester) async {
    final groups = FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: _withPeushu(),
      groups: groups,
    );

    await robot.openSocialTab();

    robot.expectScreen(SocialKeys.screen);
    expect(find.byKey(CalendarKeys.contactTile(_peushu.id)), findsOneWidget);
    expect(find.byKey(GroupKeys.groupTile('g-coloc')), findsOneWidget);
  });

  testWidgets('adding a close one from Social opens their page', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openSocialTab();
    await robot.addFromSocial(SocialKeys.addContact);
    await robot.enter(CalendarKeys.calendarName, 'Peushu');
    await robot.tap(CalendarKeys.calendarSave);

    final created = robot.calendars.calendars.last;
    expect(created.isContact, isTrue);
    robot.expectScreen(CalendarKeys.contactScreen);
    expect(find.text('Peushu'), findsWidgets);
    expect(find.byKey(CalendarKeys.contactBirthday), findsOneWidget);
  });

  testWidgets('the birthday shortcut creates a yearly all-day date', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: _withPeushu());

    await robot.openContact(_peushu.id);
    await robot.tap(CalendarKeys.contactBirthday);
    // L'éditeur arrive prérempli : il ne reste qu'à choisir la date.
    expect(
      find.widgetWithText(TextFormField, 'Anniversaire de Peushu'),
      findsOneWidget,
    );
    await robot.tap(CalendarKeys.save);

    final created = robot.calendar.items.first;
    expect(created.calendarId, _peushu.id);
    expect(created.isAllDay, isTrue);
    expect(created.rrule, 'FREQ=YEARLY');
  });

  testWidgets('the work hours shortcut repeats on weekdays', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: _withPeushu());

    await robot.openContact(_peushu.id);
    await robot.tap(CalendarKeys.contactWorkHours);
    // Le mercredi ne travaille pas : on le décoche.
    await robot.tap(CalendarKeys.repeatWeekday(DateTime.wednesday));
    await robot.tap(CalendarKeys.save);

    final created = robot.calendar.items.first;
    expect(created.calendarId, _peushu.id);
    expect(created.title, 'Travail');
    expect(created.isAllDay, isFalse);
    expect(created.rrule, 'FREQ=WEEKLY;BYDAY=MO,TU,TH,FR');
  });

  testWidgets('the rest shortcut notes a day off', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: _withPeushu());

    await robot.openContact(_peushu.id);
    await robot.tap(CalendarKeys.contactRest);
    await robot.tap(CalendarKeys.save);

    final created = robot.calendar.items.single;
    expect(created.title, 'Repos');
    expect(created.isAllDay, isTrue);
    expect(created.rrule, isNull);
  });

  testWidgets("a close one's page shows what is noted next", (tester) async {
    final calendar = FakeCalendarRepository()..seed(_birthdayIn(3));
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: _withPeushu(),
      calendar: calendar,
    );

    await robot.openContact(_peushu.id);

    expect(find.text('Anniversaire de Peushu'), findsWidgets);
  });

  testWidgets('upcoming birthdays show in Social', (tester) async {
    final calendar = FakeCalendarRepository()..seed(_birthdayIn(3));
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: _withPeushu(),
      calendar: calendar,
    );

    await robot.openSocialTab();

    expect(find.byKey(SocialKeys.upcoming), findsOneWidget);
    robot.expectText('Anniversaire de Peushu');
    expect(find.textContaining('Dans 3 jours'), findsOneWidget);
  });

  testWidgets('no upcoming section without dates to remember', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: _withPeushu());

    await robot.openSocialTab();

    expect(find.byKey(SocialKeys.upcoming), findsNothing);
  });

  testWidgets('joining a group with a code starts from Social', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openSocialTab();
    await robot.addFromSocial(GroupKeys.joinWithCode);

    robot.expectScreen(GroupKeys.joinScreen);
  });

  testWidgets("an event in a close one's calendar has no group setting", (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: _withPeushu());

    await robot.openNewEvent();
    expect(find.byKey(CalendarKeys.visibility), findsOneWidget);
    await robot.chooseCalendar(_peushu.id);

    expect(find.byKey(CalendarKeys.visibility), findsNothing);
    await robot.enter(CalendarKeys.title, 'Repos');
    await robot.tap(CalendarKeys.save);
    expect(robot.calendar.items.single.visibility, isNull);
  });

  group('repeat', () {
    testWidgets('a weekly repeat can pick its days', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn());

      await robot.openNewEvent();
      await robot.enter(CalendarKeys.title, 'Cours');
      await robot.chooseRepeat(Frequency.weekly);
      // Les jours suivent d'abord celui du rdv : on coche mardi et jeudi,
      // on décoche le reste, quel que soit le jour du test.
      const wanted = {DateTime.tuesday, DateTime.thursday};
      for (final day in wanted) {
        if (!robot.isWeekdayChosen(day)) {
          await robot.tap(CalendarKeys.repeatWeekday(day));
        }
      }
      for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
        if (!wanted.contains(day) && robot.isWeekdayChosen(day)) {
          await robot.tap(CalendarKeys.repeatWeekday(day));
        }
      }
      await robot.tap(CalendarKeys.save);

      expect(robot.calendar.items.first.rrule, 'FREQ=WEEKLY;BYDAY=TU,TH');
    });

    testWidgets('a weekly repeat can skip weeks', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn());

      await robot.openNewEvent();
      await robot.enter(CalendarKeys.title, 'Garde');
      await robot.chooseRepeat(Frequency.weekly);
      await robot.tap(CalendarKeys.repeatInterval);
      await tester.tap(find.byKey(CalendarKeys.repeatIntervalOption(2)).last);
      await robot.settle();
      await robot.tap(CalendarKeys.save);

      expect(
        robot.calendar.items.first.rrule,
        startsWith('FREQ=WEEKLY;INTERVAL=2'),
      );
    });

    testWidgets('a repeat can end on a date', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn());

      await robot.openNewEvent();
      await robot.enter(CalendarKeys.title, 'Stage');
      await robot.chooseRepeat(Frequency.daily);
      await robot.tap(CalendarKeys.repeatEnd);
      // Le sélecteur de date s'ouvre sur le jour du rdv : on le valide.
      await tester.tap(find.text('OK'));
      await robot.settle();
      expect(find.byKey(CalendarKeys.repeatEndClear), findsOneWidget);
      await robot.tap(CalendarKeys.save);

      final rule = RecurrenceRule.parse(robot.calendar.items.first.rrule!);
      expect(rule?.until, isNotNull);
    });
  });
}
