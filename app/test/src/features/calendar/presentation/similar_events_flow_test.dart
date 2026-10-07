import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

/// Aujourd'hui à 18 h locales, décalé de [weeks] semaines et [hours] heures.
DateTime _slot({int weeks = 0, int hours = 0}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 7 * weeks, 18 + hours).toUtc();
}

/// Un TD saisi séance par séance : chaque séance est un rdv ponctuel, avec
/// son propre sujet.
AgendaItem _td(String id, DateTime start, String topic) => AgendaItem(
  eventId: id,
  calendarId: FakeCalendarRepository.calendarId,
  title: 'NF19 — TD',
  location: 'UTT',
  description: topic,
  start: start,
  end: start.add(const Duration(hours: 2)),
  isAllDay: false,
  timezone: 'Europe/Paris',
);

FakeCalendarRepository _weeklyCourse() => FakeCalendarRepository()
  ..seed(_td('td-0', _slot(weeks: -1), 'Séance 0'))
  ..seed(_td('td-1', _slot(), 'Séance 1'))
  ..seed(_td('td-2', _slot(weeks: 1), 'Séance 2'))
  ..seed(_td('td-3', _slot(weeks: 2), 'Séance 3'))
  // Même titre, un autre créneau : pas semblable.
  ..seed(_td('td-x', _slot(weeks: 1, hours: -8), 'Autre groupe'));

AgendaItem _byId(FakeCalendarRepository calendar, String id) =>
    calendar.items.singleWhere((i) => i.eventId == id);

const _newAddress = '12 rue Marie Curie, 10300 Troyes';

void main() {
  testWidgets('a course entered session by session offers to change the next '
      'ones too', (tester) async {
    final calendar = _weeklyCourse();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.editEvent('NF19 — TD');
    robot.expectText('Appliquer aussi aux 2 « NF19 — TD » suivants');
    await robot.enter(CalendarKeys.location, _newAddress);
    expect(find.textContaining('recopie : lieu'), findsOneWidget);
    await robot.tap(CalendarKeys.applyToSimilar);
    await robot.tap(CalendarKeys.save);

    // Les semblables d'abord : renommé, le rdv ouvert n'en aurait plus.
    expect(calendar.writes, ['updateSimilarEvents', 'updateEvent']);
    for (final id in ['td-1', 'td-2', 'td-3']) {
      expect(_byId(calendar, id).location, _newAddress, reason: id);
    }
    expect(_byId(calendar, 'td-2').description, 'Séance 2');
    expect(_byId(calendar, 'td-3').start, _slot(weeks: 2));
    expect(_byId(calendar, 'td-0').location, 'UTT');
    expect(_byId(calendar, 'td-x').location, 'UTT');
    robot.expectText('Rendez-vous enregistré.');
  });

  testWidgets('left unticked, only the opened session changes', (tester) async {
    final calendar = _weeklyCourse();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.editEvent('NF19 — TD');
    await robot.enter(CalendarKeys.location, _newAddress);
    await robot.tap(CalendarKeys.save);

    expect(calendar.writes, ['updateEvent']);
    expect(_byId(calendar, 'td-1').location, _newAddress);
    expect(_byId(calendar, 'td-2').location, 'UTT');
  });

  testWidgets('without look-alikes, there is no box', (tester) async {
    final calendar = FakeCalendarRepository()
      ..seed(_td('td-1', _slot(), 'Séance 1'));
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.editEvent('NF19 — TD');

    expect(find.byKey(CalendarKeys.applyToSimilar), findsNothing);
  });

  testWidgets('a repeated event keeps the series question, without the box', (
    tester,
  ) async {
    final calendar = FakeCalendarRepository();
    await calendar.createEvent(
      EventDraft(
        calendarId: FakeCalendarRepository.calendarId,
        title: 'Yoga',
        start: _slot(),
        end: _slot(hours: 1),
        timezone: 'Europe/Paris',
        recurrence: const RecurrenceRule(frequency: Frequency.weekly),
      ),
    );
    calendar.calls.clear();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.editEvent('Yoga');

    expect(find.byKey(CalendarKeys.applyToSimilar), findsNothing);
    expect(calendar.calls, isNot(contains('countSimilarEvents')));
  });

  testWidgets('turning the session into a series hides the box', (
    tester,
  ) async {
    final calendar = _weeklyCourse();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), calendar: calendar);

    await robot.editEvent('NF19 — TD');
    await robot.chooseRepeat(Frequency.weekly);

    expect(find.byKey(CalendarKeys.applyToSimilar), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
  });
}
