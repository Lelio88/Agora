import 'dart:convert';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/directions/data/ign_route_times.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _home = (longitude: 4.032, latitude: 49.258);
const _station = (longitude: 4.0244, latitude: 49.2597);

/// Une réponse de l'itinéraire, telle que relevée le 2026-10-07 : les points
/// recalés sur le réseau, la durée en secondes.
http.Response _route({
  String start = '4.032089,49.257887',
  String end = '4.024097,49.258947',
  num duration = 553.1,
  int status = 200,
}) => http.Response(
  jsonEncode({
    'resource': 'bdtopo-osrm',
    'start': start,
    'end': end,
    'duration': duration,
    'timeUnit': 'second',
  }),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

IgnRouteTimes _answering(
  Future<http.Response> Function(http.Request request) answer,
) => IgnRouteTimes(MockClient(answer), spacing: Duration.zero);

void main() {
  test('asks the IGN route and rounds the trip up to the second', () async {
    final asked = <Uri>[];
    final routes = _answering((request) async {
      asked.add(request.url);
      return _route();
    });

    final walk = await routes.duration(
      from: _home,
      to: _station,
      mode: TravelMode.walk,
    );
    await routes.duration(from: _home, to: _station, mode: TravelMode.car);

    expect(walk, const Duration(seconds: 554));
    final url = asked.first;
    expect(url.host, 'data.geopf.fr');
    expect(url.path, '/navigation/itineraire');
    expect(url.queryParameters['resource'], 'bdtopo-osrm');
    expect(url.queryParameters['start'], '4.032,49.258');
    expect(url.queryParameters['end'], '4.0244,49.2597');
    expect(url.queryParameters['timeUnit'], 'second');
    expect(asked.map((url) => url.queryParameters['profile']), [
      'pedestrian',
      'car',
    ]);
  });

  test('a point moved onto the French network is no trip', () async {
    // Bruxelles : le service recale l'arrivée sur la frontière.
    final abroad = _answering((_) async => _route(end: '4.026501,50.362323'));
    // Un domicile hors de France recalé de même.
    final fromAbroad = _answering((_) async => _route(start: '4.0,50.3'));

    for (final routes in [abroad, fromAbroad]) {
      expect(
        await routes.duration(from: _home, to: _station, mode: TravelMode.car),
        isNull,
      );
    }
  });

  test('no path found is no trip', () async {
    final routes = _answering(
      (_) async =>
          http.Response('{"error":{"message":" No path found "}}', 404),
    );

    expect(
      await routes.duration(from: _home, to: _station, mode: TravelMode.car),
      isNull,
    );
  });

  test('refusals and failures become typed errors', () async {
    final cases = <Future<http.Response> Function(http.Request), Matcher>{
      (_) async => http.Response('{}', 429): isA<RateLimitedException>(),
      (_) async => http.Response('{}', 500): isA<UnknownException>(),
      (_) async => http.Response('<html>', 200): isA<UnknownException>(),
      (_) async => throw http.ClientException('Connection refused'):
          isA<NetworkException>(),
    };
    for (final MapEntry(key: answer, value: error) in cases.entries) {
      await expectLater(
        _answering(answer)
            .duration(from: _home, to: _station, mode: TravelMode.car),
        throwsA(error),
      );
    }
  });
}
