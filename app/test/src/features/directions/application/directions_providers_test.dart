import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/directions/application/directions_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_directions.dart';
import '../../../../helpers/fakes.dart';

const _home = Address(label: 'Chez moi', longitude: 4.0318, latitude: 49.2575);
const _royale = Address(
  label: '3 Place Royale 51100 Reims',
  longitude: 4.0335,
  latitude: 49.2531,
);
const _target = (eventKey: 'evt', location: '3 place Royale, Reims');

/// Le trajet jusqu'au rdv, pour une personne qui a un domicile.
Future<TravelEstimate?> _estimate(
  FakeRouteTimes routes, {
  FakeTravelRepository? travel,
}) async {
  final auth = FakeAuthRepository(
    signedInAs: const AppUser(id: FakeAuthRepository.userId, email: 'z@t.l'),
  );
  addTearDown(auth.dispose);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      travelRepositoryProvider.overrideWithValue(
        travel ?? FakeTravelRepository(home: _home),
      ),
      addressSearchProvider.overrideWithValue(
        FakeAddressSearch(const [], {_target.location: _royale}),
      ),
      routeTimesProvider.overrideWithValue(routes),
    ],
  );
  addTearDown(container.dispose);
  final listened = container.listen(eventTravelProvider(_target), (_, _) {});
  addTearDown(listened.close);
  return container.read(eventTravelProvider(_target).future);
}

void main() {
  group('automatic', () {
    test('walks a short trip, without asking for the car', () async {
      final routes = FakeRouteTimes(const {
        TravelMode.walk: Duration(minutes: 12),
        TravelMode.car: Duration(minutes: 6),
      });

      expect(
        await _estimate(routes),
        const TravelEstimate(TravelMode.walk, Duration(minutes: 12)),
      );
      expect(routes.asked.map((asked) => asked.mode), [TravelMode.walk]);
      // Le domicile part arrondi.
      expect(routes.asked.single.from, (longitude: 4.032, latitude: 49.258));
    });

    test('drives a long one', () async {
      final routes = FakeRouteTimes(const {
        TravelMode.walk: Duration(minutes: 40),
        TravelMode.car: Duration(minutes: 9),
      });

      expect(
        await _estimate(routes),
        const TravelEstimate(TravelMode.car, Duration(minutes: 9)),
      );
    });

    test('walks a long one when the car has no route', () async {
      final routes = FakeRouteTimes(const {
        TravelMode.walk: Duration(minutes: 40),
      });

      expect(
        await _estimate(routes),
        const TravelEstimate(TravelMode.walk, Duration(minutes: 40)),
      );
    });

    test('still drives when the walk could not be worked out', () async {
      final routes = FakeRouteTimes(
        const {TravelMode.car: Duration(minutes: 9)},
        const {TravelMode.walk: RateLimitedException()},
      );

      expect(
        await _estimate(routes),
        const TravelEstimate(TravelMode.car, Duration(minutes: 9)),
      );
    });
  });

  test('a chosen mode is the only one asked', () async {
    final routes = FakeRouteTimes(const {
      TravelMode.walk: Duration(minutes: 12),
      TravelMode.car: Duration(minutes: 6),
    });
    final travel = FakeTravelRepository(home: _home);
    travel.choices['evt'] = TravelChoice.car;

    expect(
      await _estimate(routes, travel: travel),
      const TravelEstimate(TravelMode.car, Duration(minutes: 6)),
    );
    expect(routes.asked.map((asked) => asked.mode), [TravelMode.car]);
  });

  test('« no trip » asks nothing', () async {
    final routes = FakeRouteTimes(const {TravelMode.car: Duration(minutes: 6)});
    final travel = FakeTravelRepository(home: _home);
    travel.choices['evt'] = TravelChoice.none;

    expect(await _estimate(routes, travel: travel), isNull);
    expect(routes.asked, isEmpty);
  });
}
