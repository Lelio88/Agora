/// Durée d'un trajet entre deux points, par le service d'itinéraire.
///
/// Invariants : seules des `AppException` en sortent ; un trajet
/// impossible (aucun chemin, ou un point hors du réseau couvert) n'est pas
/// une erreur, c'est `null`.
library;

import 'package:agora/src/features/directions/domain/travel.dart';

abstract interface class RouteTimes {
  /// La durée de [from] à [to] en [mode], ou `null` sans trajet possible.
  Future<Duration?> duration({
    required GeoPoint from,
    required GeoPoint to,
    required TravelMode mode,
  });
}
