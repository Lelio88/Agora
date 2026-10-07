/// Providers des trajets : les réglages de l'utilisateur connecté, la
/// recherche d'adresses, et le temps de trajet vers le lieu d'un rdv.
///
/// Choix non évidents :
/// - [travelSettingsProvider] suit le compte connecté
///   (`currentUserIdProvider`) : il se vide à la déconnexion et se relit si
///   le compte change, mais pas à chaque rafraîchissement du jeton ;
/// - les lieux ([placeProvider]) et les durées ([routeDurationProvider]) se
///   gardent en mémoire une fois trouvés, pour toute la vie de l'app : une
///   durée ne dépend que de ses deux points et de son mode (ni trafic ni
///   heure), et l'agenda en redemande à chaque page. Ils se retiennent dès
///   la demande partie, pas à son retour : une page quittée en plein calcul
///   garde le résultat au lieu de le perdre et de le redemander. Une erreur
///   les relâche, pour qu'une prochaine lecture réessaie ;
/// - aucune recherche ratée n'est relancée d'elle-même : le service de
///   l'IGN limite les appels par adresse IP. La frappe suivante, ou la
///   prochaine ouverture de l'écran, en refera une ;
/// - le mode automatique demande d'abord la marche, puis la voiture si la
///   marche dépasse le quart d'heure : un seul appel pour un rdv proche.
///   Une marche en échec n'empêche pas la voiture, et une voiture sans
///   chemin rend la marche, même longue.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/route_times.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/domain/travel_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final travelRepositoryProvider = Provider<TravelRepository>(
  (ref) => throw UnimplementedError(
    'travelRepositoryProvider must be overridden at the composition root.',
  ),
);

final addressSearchProvider = Provider<AddressSearch>(
  (ref) => throw UnimplementedError(
    'addressSearchProvider must be overridden at the composition root.',
  ),
);

final routeTimesProvider = Provider<RouteTimes>(
  (ref) => throw UnimplementedError(
    'routeTimesProvider must be overridden at the composition root.',
  ),
);

/// Les réglages de trajet de l'utilisateur connecté, ou `null` sans
/// domicile.
final travelSettingsProvider = FutureProvider<TravelSettings?>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(travelRepositoryProvider).fetchSettings(userId);
});

/// Le domicile de l'utilisateur connecté, ou `null`.
final homeProvider = FutureProvider<Address?>(
  (ref) async => (await ref.watch(travelSettingsProvider.future))?.home,
);

/// Les modes choisis par l'utilisateur connecté, par rdv.
final travelChoicesProvider = FutureProvider<Map<String, TravelChoice>>((
  ref,
) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return const {};
  return ref.watch(travelRepositoryProvider).fetchChoices(userId);
});

/// Les adresses proposées pour un texte tapé.
final addressSuggestionsProvider = FutureProvider.autoDispose
    .family<List<Address>, String>(
      (ref, text) => ref.watch(addressSearchProvider).search(text),
      retry: (_, _) => null,
    );

/// Le lieu que désigne le texte d'un rdv, ou `null`.
final placeProvider = FutureProvider.autoDispose.family<Address?, String>((
  ref,
  location,
) async {
  final kept = ref.keepAlive();
  try {
    return await ref.watch(addressSearchProvider).locate(location);
  } on Exception {
    kept.close();
    rethrow;
  }
}, retry: (_, _) => null);

/// Un trajet à calculer : ses deux points et son mode.
typedef RouteQuery = ({GeoPoint from, GeoPoint to, TravelMode mode});

/// La durée d'un trajet, ou `null` s'il est impossible.
final routeDurationProvider = FutureProvider.autoDispose
    .family<Duration?, RouteQuery>((ref, query) async {
      final kept = ref.keepAlive();
      try {
        return await ref
            .watch(routeTimesProvider)
            .duration(from: query.from, to: query.to, mode: query.mode);
      } on Exception {
        kept.close();
        rethrow;
      }
    }, retry: (_, _) => null);

/// Un rdv dont on veut le trajet : la clé de son choix (le rdv, ou le rdv
/// maître de sa série) et son lieu.
typedef TravelTarget = ({String eventKey, String location});

/// Le trajet de l'utilisateur connecté jusqu'au rdv : son domicile, le mode
/// choisi pour le rdv ou son réglage, le lieu reconnu. `null` sans
/// domicile, sans trajet voulu (« aucun »), ou sans lieu ni chemin trouvé.
final eventTravelProvider = FutureProvider.autoDispose
    .family<TravelEstimate?, TravelTarget>((ref, target) async {
      final settings = await ref.watch(travelSettingsProvider.future);
      if (settings == null) return null;
      final choices = await ref.watch(travelChoicesProvider.future);
      final choice = choices[target.eventKey];
      if (choice == TravelChoice.none) return null;
      final place = await ref.watch(placeProvider(target.location).future);
      if (place == null) return null;
      final from = roundedOrigin(settings.home);
      Future<Duration?> by(TravelMode mode) => ref.watch(
        routeDurationProvider((from: from, to: pointOf(place), mode: mode))
            .future,
      );
      final mode = choice?.mode ?? settings.preference.mode;
      if (mode != null) {
        final duration = await by(mode);
        return duration == null ? null : TravelEstimate(mode, duration);
      }
      Duration? walk;
      try {
        walk = await by(TravelMode.walk);
      } on AppException {
        // La voiture peut encore répondre.
      }
      if (walk != null && autoMode(walk) == TravelMode.walk) {
        return TravelEstimate(TravelMode.walk, walk);
      }
      final car = await by(TravelMode.car);
      if (car != null) return TravelEstimate(TravelMode.car, car);
      return walk == null ? null : TravelEstimate(TravelMode.walk, walk);
    }, retry: (_, _) => null);
