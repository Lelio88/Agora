import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
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

/// Mardi de la semaine affichée, à [hour] h locales.
DateTime _tuesdayThisWeekAt(int hour) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + 1, hour).toUtc();
}

AgendaItem _event(String title, {String? location}) {
  final start = _tuesdayThisWeekAt(10);
  return AgendaItem(
    eventId: 'evt-$title',
    calendarId: FakeCalendarRepository.calendarId,
    title: title,
    location: location,
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'Europe/Paris',
  );
}

void main() {
  testWidgets('a saved event with a place offers « Y aller »', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()
        ..seed(_event('Dentiste', location: '3 place Royale, Reims')),
    );

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.goThere);
    await robot.tap(DirectionsKeys.goThere);
    await robot.tap(DirectionsKeys.googleMaps);

    final link = robot.links.opened.single;
    expect(link.queryParameters['destination'], '3 place Royale, Reims');
    // Sans adresse saisie : l'app d'itinéraire part de la position.
    expect(link.queryParameters.containsKey('origin'), isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('no place, no button', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()..seed(_event('Sieste')),
    );

    await robot.tapEvent('Sieste');

    expect(find.byKey(DirectionsKeys.goThere), findsNothing);
  });

  testWidgets('a new event does not offer it yet', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openNewEvent();
    await robot.enter(CalendarKeys.location, 'Gare de Reims');

    expect(find.byKey(DirectionsKeys.goThere), findsNothing);
  });

  testWidgets('says so when no app can open the route', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      calendar: FakeCalendarRepository()
        ..seed(_event('Dentiste', location: 'Reims')),
      links: FakeLinkOpener(succeeds: false),
    );

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.goThere);
    await robot.tap(DirectionsKeys.goThere);
    await robot.tap(DirectionsKeys.citymapper);

    robot.expectText("Aucune app n'a pu ouvrir l'itinéraire.");
  });
}
