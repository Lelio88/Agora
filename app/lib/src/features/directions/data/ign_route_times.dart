/// [RouteTimes] adossé à l'itinéraire de la Géoplateforme de l'IGN
/// (`data.geopf.fr/navigation/itineraire`, ressource `bdtopo-osrm`).
///
/// Choix non évidents :
/// - voiture (`car`) et marche (`pedestrian`) : les deux profils du
///   service. Ses durées ne tiennent compte ni du trafic ni de l'heure ;
/// - un appel à la fois, espacés de [spacing] : le service limite les
///   appels par adresse IP (5 par seconde), et un agenda chargé en demande
///   plusieurs d'un coup ;
/// - le service recale sur son réseau un point qui en sort, sans le dire :
///   un départ ou une arrivée recalés au-delà de `snapTolerance` font un
///   trajet impossible (`null`), comme « aucun chemin » (404) ;
/// - la durée est arrondie à la seconde supérieure : mieux vaut partir un
///   peu tôt.
///
/// Invariant : seules des `AppException` en sortent, sans les points
/// demandés.
library;

import 'dart:convert';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:agora/src/features/directions/domain/route_times.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:http/http.dart' as http;

final class IgnRouteTimes implements RouteTimes {
  IgnRouteTimes(this._client, {this.spacing = _defaultSpacing});

  final http.Client _client;

  /// L'attente entre deux appels.
  final Duration spacing;

  static const _defaultSpacing = Duration(milliseconds: 250);
  static const _timeout = Duration(seconds: 15);

  /// La fin du dernier appel, et de l'attente qui le suit.
  Future<void> _turn = Future.value();

  @override
  Future<Duration?> duration({
    required GeoPoint from,
    required GeoPoint to,
    required TravelMode mode,
  }) {
    final result = _turn.then((_) => _ask(from, to, mode));
    _turn = result.then(
      (_) => Future<void>.delayed(spacing),
      onError: (Object _) => Future<void>.delayed(spacing),
    );
    return result;
  }

  Future<Duration?> _ask(GeoPoint from, GeoPoint to, TravelMode mode) async {
    final url = Uri.https('data.geopf.fr', '/navigation/itineraire', {
      'resource': 'bdtopo-osrm',
      'profile': switch (mode) {
        TravelMode.car => 'car',
        TravelMode.walk => 'pedestrian',
      },
      'optimization': 'fastest',
      'start': _coordinates(from),
      'end': _coordinates(to),
      'getSteps': 'false',
      'timeUnit': 'second',
      'distanceUnit': 'meter',
    });
    final http.Response response;
    try {
      response = await _client.get(url).timeout(_timeout);
    } on Exception catch (error) {
      throw looksLikeNetworkError(error.toString())
          ? const NetworkException()
          : const UnknownException();
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode == 429) throw const RateLimitedException();
    if (response.statusCode != 200) throw const UnknownException();
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const UnknownException();
    }
    if (json case {
      'start': final String start,
      'end': final String end,
      'duration': final num seconds,
    }) {
      final snappedStart = _parse(start);
      final snappedEnd = _parse(end);
      if (snappedStart == null || snappedEnd == null) {
        throw const UnknownException();
      }
      if (!isNear(from, snappedStart) || !isNear(to, snappedEnd)) return null;
      return Duration(seconds: seconds.ceil());
    }
    throw const UnknownException();
  }

  static String _coordinates(GeoPoint point) =>
      '${point.longitude},${point.latitude}';

  /// Un point « longitude,latitude » de la réponse.
  static GeoPoint? _parse(String text) {
    final parts = text.split(',');
    if (parts.length != 2) return null;
    final longitude = double.tryParse(parts[0]);
    final latitude = double.tryParse(parts[1]);
    if (longitude == null || latitude == null) return null;
    return (longitude: longitude, latitude: latitude);
  }
}
