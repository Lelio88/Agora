import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the home leaves rounded to about a hundred metres', () {
    const home = Address(
      label: 'Chez moi',
      longitude: 4.031847,
      latitude: 49.257517,
    );

    expect(roundedOrigin(home), (longitude: 4.032, latitude: 49.258));
  });

  test('automatic walks up to a quarter of an hour, drives beyond', () {
    expect(autoMode(const Duration(minutes: 15)), TravelMode.walk);
    expect(autoMode(const Duration(minutes: 16)), TravelMode.car);
    // Pas de chemin à pied (hors de portée) : la voiture.
    expect(autoMode(null), TravelMode.car);
  });

  test('a preference or a choice names its mode, automatic none', () {
    expect(TravelPreference.auto.mode, isNull);
    expect(TravelPreference.walk.mode, TravelMode.walk);
    expect(TravelChoice.car.mode, TravelMode.car);
    expect(TravelChoice.none.mode, isNull);
    expect(TravelPreference.fromCode('bike'), TravelPreference.auto);
    expect(TravelChoice.fromCode('walk'), TravelChoice.walk);
    expect(TravelChoice.fromCode(null), isNull);
  });

  test('the departure is the start minus the trip, to the minute', () {
    final start = DateTime(2026, 10, 8, 10);

    expect(
      departureFor(start, const Duration(minutes: 12, seconds: 30)),
      DateTime(2026, 10, 8, 9, 47),
    );
  });

  test('a point moved more than half a kilometre is not the one asked', () {
    const reims = (longitude: 4.0317, latitude: 49.2583);

    expect(isNear(reims, (longitude: 4.0322, latitude: 49.2585)), isTrue);
    // Bruxelles, recalé par le service sur la frontière près de Givet.
    expect(
      isNear(
        (longitude: 4.3517, latitude: 50.8503),
        (longitude: 4.0265, latitude: 50.3623),
      ),
      isFalse,
    );
  });

  group('a place found for an event', () {
    test('counts when the text names its town or postcode', () {
      expect(
        mentionsPlace('Gare de Reims', cities: ['Reims'], postcodes: ['51100']),
        isTrue,
      );
      expect(
        mentionsPlace(
          '12 rue de Vesle, 51100',
          cities: ['Reims'],
          postcodes: ['51100'],
        ),
        isTrue,
      );
      expect(
        mentionsPlace(
          'Mairie de SAINT-LÔ',
          cities: ['Saint-Lô'],
          postcodes: ['50000'],
        ),
        isTrue,
      );
    });

    test('does not count when the town comes from nowhere in the text', () {
      // « Chez Paul » : une rue d'Orléat, sans rapport avec le rdv.
      expect(
        mentionsPlace('Chez Paul', cities: ['Orléat'], postcodes: ['63190']),
        isFalse,
      );
      // Un mot qui contient la commune n'est pas la commune.
      expect(
        mentionsPlace('Reimsbourg', cities: ['Reims'], postcodes: ['51100']),
        isFalse,
      );
    });
  });
}
