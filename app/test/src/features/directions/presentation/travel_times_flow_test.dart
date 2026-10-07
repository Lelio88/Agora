import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/presentation/directions_keys.dart';
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

const _home = Address(
  label: "1 Place de l'Hôtel de Ville 51100 Reims",
  longitude: 4.031847,
  latitude: 49.257517,
);

const _royale = Address(
  label: '3 Place Royale 51100 Reims',
  longitude: 4.0335,
  latitude: 49.2531,
);

const _place = '3 place Royale, Reims';

/// Aujourd'hui à 10 h locales, visible dans la vue par défaut.
AgendaItem _dentist({String location = _place}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 10).toUtc();
  return AgendaItem(
    eventId: 'evt-dentiste',
    calendarId: FakeCalendarRepository.calendarId,
    title: 'Dentiste',
    location: location,
    start: start,
    end: start.add(const Duration(hours: 1)),
    isAllDay: false,
    timezone: 'Europe/Paris',
  );
}

/// L'agenda d'une personne qui a un domicile, avec le rdv chez le dentiste
/// à 12 min à pied et 6 min en voiture.
Future<AgoraRobot> _pumpWithTrips(
  WidgetTester tester, {
  FakeTravelRepository? travel,
  String location = _place,
}) async {
  final robot = AgoraRobot(tester);
  await robot.pumpApp(
    auth: _signedIn(),
    travel: travel ?? FakeTravelRepository(home: _home),
    addressSearch: FakeAddressSearch(const [], const {_place: _royale}),
    routeTimes: FakeRouteTimes(const {
      TravelMode.walk: Duration(minutes: 12),
      TravelMode.car: Duration(minutes: 6),
    }),
    calendar: FakeCalendarRepository()..seed(_dentist(location: location)),
  );
  return robot;
}

bool _isChosen(WidgetTester tester, TravelChoice choice) => tester
    .widget<ChoiceChip>(find.byKey(DirectionsKeys.choice(choice)))
    .selected;

void main() {
  testWidgets('the preferred mode and the agenda switch are kept', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    final travel = FakeTravelRepository(home: _home);
    await robot.pumpApp(auth: _signedIn(), travel: travel);

    await robot.openTravel();
    await robot.tap(DirectionsKeys.preference(TravelPreference.walk));
    await robot.tap(DirectionsKeys.showInAgenda);

    expect(travel.settings?.preference, TravelPreference.walk);
    expect(travel.settings?.showInAgenda, isFalse);
    expect(robot.logger.errorCount, 0);
  });

  testWidgets('an event sheet gives both trips, and when to leave', (
    tester,
  ) async {
    final robot = await _pumpWithTrips(tester);

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.departure);

    robot.expectText('≈ 6 min');
    robot.expectText('≈ 12 min');
    // Automatique : 12 min à pied, sous le quart d'heure.
    expect(_isChosen(tester, TravelChoice.walk), isTrue);
    robot.expectText('Pars à 09:48');
    robot.expectText('Vers 3 Place Royale 51100 Reims');
  });

  testWidgets('a mode chosen for an event is kept for it', (tester) async {
    final travel = FakeTravelRepository(home: _home);
    final robot = await _pumpWithTrips(tester, travel: travel);

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.departure);
    await robot.tap(DirectionsKeys.choice(TravelChoice.car));

    expect(travel.choices, {'evt-dentiste': TravelChoice.car});
    expect(_isChosen(tester, TravelChoice.car), isTrue);
    robot.expectText('Pars à 09:54');
  });

  testWidgets('a place it cannot find is said, not guessed', (tester) async {
    final robot = await _pumpWithTrips(tester, location: 'Chez Paul');

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.placeUnknown);

    expect(find.byKey(DirectionsKeys.departure), findsNothing);
    expect(find.byKey(DirectionsKeys.choice(TravelChoice.car)), findsNothing);
  });

  testWidgets('without a home, the sheet invites to set one', (tester) async {
    final robot = await _pumpWithTrips(tester, travel: FakeTravelRepository());

    await robot.tapEvent('Dentiste');
    await robot.scrollTo(DirectionsKeys.setHomeHint);

    expect(robot.routeTimes.asked, isEmpty);
  });

  testWidgets('the agenda draws the trip just before the event', (
    tester,
  ) async {
    await _pumpWithTrips(tester);

    expect(find.byKey(DirectionsKeys.strip('evt-dentiste')), findsOneWidget);
  });

  testWidgets('no trip in the agenda once it is switched off', (tester) async {
    await _pumpWithTrips(
      tester,
      travel: FakeTravelRepository(home: _home, showInAgenda: false),
    );

    expect(find.byKey(DirectionsKeys.strip('evt-dentiste')), findsNothing);
  });

  testWidgets('no trip in the agenda for an event with no trip chosen', (
    tester,
  ) async {
    final travel = FakeTravelRepository(home: _home);
    travel.choices['evt-dentiste'] = TravelChoice.none;

    await _pumpWithTrips(tester, travel: travel);

    expect(find.byKey(DirectionsKeys.strip('evt-dentiste')), findsNothing);
  });
}
