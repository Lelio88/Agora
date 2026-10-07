import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_calendar_repository.dart';
import '../../../../helpers/fake_directions.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

const _townHall = Address(
  label: "1 Place de l'Hôtel de Ville 51100 Reims",
  longitude: 4.031847,
  latitude: 49.257517,
);

const _station = Address(
  label: 'Place de la Gare 51100 Reims',
  longitude: 4.024,
  latitude: 49.259,
);

AgendaItem _dentist() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 10).toUtc();
  return AgendaItem(
    eventId: 'evt-dentiste',
    calendarId: FakeCalendarRepository.calendarId,
    title: 'Dentiste',
    location: '3 place Royale, Reims',
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'Europe/Paris',
  );
}

void main() {
  testWidgets('a home picked among the suggestions is kept on the account', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    final home = FakeTravelRepository();
    await robot.pumpApp(
      auth: _signedIn(),
      travel: home,
      addressSearch: FakeAddressSearch([_townHall, _station]),
    );

    await robot.openTravel();
    await robot.searchHome('hôtel de ville');
    await robot.tap(DirectionsKeys.suggestion(0));

    expect(home.home, _townHall);
    expect(
      find.descendant(
        of: find.byKey(DirectionsKeys.home),
        matching: find.text(_townHall.label),
      ),
      findsOneWidget,
    );
    // Choisie, l'adresse quitte le champ et les suggestions disparaissent.
    expect(find.byKey(DirectionsKeys.suggestion(0)), findsNothing);
    await robot.goBack();
    expect(
      find.descendant(
        of: find.byKey(ProfileKeys.travel),
        matching: find.text(_townHall.label),
      ),
      findsOneWidget,
    );
    expect(robot.logger.errorCount, 0);
  });

  testWidgets('the home can be forgotten', (tester) async {
    final robot = AgoraRobot(tester);
    final home = FakeTravelRepository(home: _townHall);
    await robot.pumpApp(auth: _signedIn(), travel: home);

    await robot.openTravel();
    await robot.tap(DirectionsKeys.clearHome);

    expect(home.home, isNull);
    expect(find.byKey(DirectionsKeys.home), findsNothing);
  });

  testWidgets('a search that fails says so, and the next one works', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    final search = FakeAddressSearch([_station])
      ..nextError = const NetworkException();
    await robot.pumpApp(auth: _signedIn(), addressSearch: search);

    await robot.openTravel();
    await robot.searchHome('gare');

    robot.expectText('Impossible de joindre le serveur. Vérifie ta connexion.');
    expect(find.byKey(DirectionsKeys.suggestion(0)), findsNothing);

    await robot.searchHome('place de la gare');

    expect(find.byKey(DirectionsKeys.suggestion(0)), findsOneWidget);
  });

  testWidgets('a text too short to search asks nothing', (tester) async {
    final robot = AgoraRobot(tester);
    final search = FakeAddressSearch([_station]);
    await robot.pumpApp(auth: _signedIn(), addressSearch: search);

    await robot.openTravel();
    await robot.searchHome('ga');

    expect(search.searched, isEmpty);
    expect(find.byKey(DirectionsKeys.suggestion(0)), findsNothing);
  });

  testWidgets('« Y aller » leaves from home unless told otherwise', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      travel: FakeTravelRepository(home: _townHall),
      calendar: FakeCalendarRepository()..seed(_dentist()),
    );

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.goThere);
    await robot.tap(DirectionsKeys.goThere);
    await robot.tap(DirectionsKeys.googleMaps);

    expect(robot.links.opened.last.queryParameters['origin'], _townHall.label);

    // « Depuis ma position » vide le champ : l'app d'itinéraire part alors
    // de la position du téléphone.
    await robot.tap(DirectionsKeys.fromMyPosition);
    await robot.tap(DirectionsKeys.googleMaps);

    expect(
      robot.links.opened.last.queryParameters.containsKey('origin'),
      isFalse,
    );
    expect(find.byType(SnackBar), findsNothing);
  });
}
