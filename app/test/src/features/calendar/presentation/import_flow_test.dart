import 'package:agora/src/exceptions/app_exception.dart';
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

const _secretLink = 'webcal://calendar.example.com/private-7f3a9c/basic.ics';

const _personal = UserCalendar(
  id: FakeCalendarRepository.calendarId,
  name: 'Agenda',
  kind: CalendarKind.native,
);
final _work = UserCalendar(
  id: 'cal-work',
  name: 'Boulot',
  kind: CalendarKind.ics,
  colorHex: '#1E88E5',
  lastSyncedAt: DateTime.utc(2026, 9, 22, 12, 5),
);
const _broken = UserCalendar(
  id: 'cal-broken',
  name: 'Club',
  kind: CalendarKind.ics,
  syncError: FeedSyncError.notFound,
);

/// Mardi de la semaine affichée par défaut (elle commence le lundi), à
/// 18 h locales : visible quel que soit le jour du test.
DateTime _tuesdayThisWeek18h() {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + 1, 18).toUtc();
}

AgendaItem _standup() {
  final start = _tuesdayThisWeek18h();
  return AgendaItem(
    eventId: 'evt-standup',
    calendarId: _work.id,
    title: 'Point hebdo',
    location: 'Salle 2',
    start: start,
    end: start.add(const Duration(minutes: 30)),
    isAllDay: false,
    timezone: 'Europe/Paris',
  );
}

Future<void> _fillImport(
  AgoraRobot robot, {
  String link = _secretLink,
  String name = 'Boulot',
}) async {
  await robot.openCalendars();
  await robot.tap(CalendarKeys.importCalendar);
  robot.expectScreen(CalendarKeys.importScreen);
  await robot.enter(CalendarKeys.importUrl, link);
  await robot.enter(CalendarKeys.importName, name);
  await robot.tap(CalendarKeys.importSave);
}

void main() {
  testWidgets('importing a calendar adds it, waiting for its first sync', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await _fillImport(robot);

    expect(robot.calendars.importedUrls, [_secretLink]);
    final imported = robot.calendars.calendars.last;
    expect(imported.kind, CalendarKind.ics);
    expect(imported.name, 'Boulot');
    robot.expectText(
      'Agenda importé : ses rendez-vous arrivent dans un instant.',
    );
    robot.expectText('Première synchronisation en cours…');
    expect(
      find.textContaining('private-7f3a9c'),
      findsNothing,
      reason: 'the link is a secret: never shown once imported',
    );
  });

  testWidgets('an import link must be https or webcal', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await _fillImport(robot, link: 'http://calendar.example.com/a.ics');

    robot.expectText(
      'Collez un lien qui commence par https:// ou webcal://, sans espace.',
    );
    expect(robot.calendars.calls, isNot(contains('importCalendar')));
  });

  testWidgets('a link the server refuses is explained', (tester) async {
    final calendars = FakeCalendarsRepository();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: calendars);

    await robot.openCalendars();
    calendars.nextError = const TooManyFeedsException();
    await robot.tap(CalendarKeys.importCalendar);
    await robot.enter(CalendarKeys.importUrl, _secretLink);
    await robot.enter(CalendarKeys.importName, 'Boulot');
    await robot.tap(CalendarKeys.importSave);

    robot.expectText(
      'Vous avez déjà importé 10 agendas : supprimez-en un pour en ajouter '
      'un autre.',
    );
  });

  testWidgets('the help tells where to find the link', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    await robot.tap(CalendarKeys.importCalendar);
    await robot.tap(CalendarKeys.importHelp);

    expect(find.textContaining('Adresse secrète au format iCal'), findsOne);
    expect(find.textContaining('Publier un calendrier'), findsOne);
    expect(find.textContaining('Calendrier public'), findsOne);
  });

  testWidgets('my calendars show when an import last synced, or why not', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _work, _broken]),
    );

    await robot.openCalendars();

    expect(find.textContaining('Synchronisé le'), findsOne);
    robot.expectText(
      "Lien introuvable : l'agenda a été supprimé ou son lien a changé.",
    );
  });

  testWidgets('the sync state updates live once the worker has run', (
    tester,
  ) async {
    final calendars = FakeCalendarsRepository([_personal]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendars: calendars);

    await _fillImport(robot);
    robot.expectText('Première synchronisation en cours…');
    final imported = calendars.calendars.last;
    calendars.pushFromServer(
      UserCalendar(
        id: imported.id,
        name: imported.name,
        kind: CalendarKind.ics,
        syncError: FeedSyncError.notCalendar,
      ),
    );
    await robot.settle();

    expect(find.text('Première synchronisation en cours…'), findsNothing);
    robot.expectText('Ce lien ne mène pas à un agenda iCal.');
  });

  testWidgets('an imported calendar can be synced again on demand', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendars: FakeCalendarsRepository([_personal, _work]),
    );

    await robot.openCalendars();
    await robot.tap(CalendarKeys.calendarTile(_work.id));
    await robot.tap(CalendarKeys.calendarSyncNow);

    expect(robot.calendars.calls, contains('syncNow'));
    robot.expectText('Synchronisation demandée.');
  });

  testWidgets('a native calendar offers no sync', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openCalendars();
    await robot.tap(CalendarKeys.calendarTile(_personal.id));

    expect(find.byKey(CalendarKeys.calendarSyncNow), findsNothing);
  });

  testWidgets(
    'an imported event opens read-only; only its visibility changes',
    (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(
        auth: _signedIn(),
        calendar: FakeCalendarRepository()..seed(_standup()),
        calendars: FakeCalendarsRepository([_personal, _work]),
      );

      await robot.tapEvent('Point hebdo');

      robot.expectScreen(CalendarKeys.importedEventSheet);
      expect(find.byKey(CalendarKeys.editor), findsNothing);
      robot.expectText('Salle 2');
      robot.expectText('Boulot');
      await robot.tap(CalendarKeys.importedEventVisibility);
      await tester.tap(find.text('Occupé, sans détail').last);
      await robot.settle();
      await robot.tap(CalendarKeys.importedEventSave);

      expect(robot.calendar.writes, ['setEventVisibility']);
      expect(robot.calendar.items.single.visibility, EventVisibility.busy);
      robot.expectText('Réglage enregistré.');
    },
  );

  testWidgets('an imported event cannot be saved without a change', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()..seed(_standup()),
      calendars: FakeCalendarsRepository([_personal, _work]),
    );

    await robot.tapEvent('Point hebdo');
    final save = tester.widget<FilledButton>(
      find.byKey(CalendarKeys.importedEventSave),
    );

    expect(save.onPressed, isNull);
    expect(robot.calendar.writes, isEmpty);
  });
}
