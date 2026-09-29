import 'package:agora/src/features/directions/domain/directions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final arrival = DateTime.utc(2026, 10, 6, 17, 45);

  group('Google Maps', () {
    test('asks for a public transport route to the place', () {
      final link = directionsLink(
        DirectionsApp.googleMaps,
        const Trip(destination: '12 rue de Vesle, Reims'),
      );

      expect(link.host, 'www.google.com');
      expect(link.path, '/maps/dir/');
      expect(link.queryParameters, {
        'api': '1',
        'destination': '12 rue de Vesle, Reims',
        'travelmode': 'transit',
      });
    });

    test('starts from the typed address, or else from where the phone is', () {
      final from = directionsLink(
        DirectionsApp.googleMaps,
        const Trip(destination: 'Gare de Reims', origin: '  Place Drouet  '),
      );
      final here = directionsLink(
        DirectionsApp.googleMaps,
        const Trip(destination: 'Gare de Reims', origin: '   '),
      );

      expect(from.queryParameters['origin'], 'Place Drouet');
      expect(here.queryParameters.containsKey('origin'), isFalse);
    });
  });

  group('Citymapper', () {
    test('carries the wanted arrival time', () {
      final link = directionsLink(
        DirectionsApp.citymapper,
        Trip(destination: 'Gare de Reims', arriveBy: arrival),
      );

      expect(link.host, 'citymapper.com');
      expect(link.path, '/directions');
      expect(link.queryParameters['endaddress'], 'Gare de Reims');
      expect(link.queryParameters['arrival_time'], '2026-10-06T17:45:00.000Z');
      expect(link.queryParameters.containsKey('startaddress'), isFalse);
    });

    test('passes a typed departure, and no time when none is wanted', () {
      final link = directionsLink(
        DirectionsApp.citymapper,
        const Trip(destination: 'Gare de Reims', origin: 'Place Drouet'),
      );

      expect(link.queryParameters['startaddress'], 'Place Drouet');
      expect(link.queryParameters.containsKey('arrival_time'), isFalse);
    });
  });

  test('another app receives the place alone, through a geo link', () {
    final link = directionsLink(
      DirectionsApp.other,
      const Trip(destination: 'Gare de Reims'),
    );

    expect(link.toString(), 'geo:0,0?q=Gare%20de%20Reims');
  });

  group('arrival wanted', () {
    final now = DateTime.utc(2026, 10, 6, 12);

    test('is the start of an upcoming timed event', () {
      expect(wantedArrival(start: arrival, isAllDay: false, now: now), arrival);
    });

    test('is none for an all-day event or one already begun', () {
      expect(wantedArrival(start: arrival, isAllDay: true, now: now), isNull);
      expect(
        wantedArrival(
          start: now.subtract(const Duration(minutes: 1)),
          isAllDay: false,
          now: now,
        ),
        isNull,
      );
    });
  });
}
