import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/route_times.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/domain/travel_repository.dart';

/// Réglages de trajet en mémoire, comme les tables `travel_settings` et
/// `event_travel_modes` d'un seul utilisateur.
class FakeTravelRepository implements TravelRepository {
  FakeTravelRepository({
    Address? home,
    TravelPreference preference = TravelPreference.auto,
    bool showInAgenda = true,
  }) : settings = home == null
           ? null
           : TravelSettings(
               home: home,
               preference: preference,
               showInAgenda: showInAgenda,
             );

  /// Les réglages, tels que les écrans les ont laissés.
  TravelSettings? settings;
  final choices = <String, TravelChoice>{};
  AppException? nextError;

  Address? get home => settings?.home;

  @override
  Future<TravelSettings?> fetchSettings(String userId) async => settings;

  @override
  Future<void> saveHome(Address home) async {
    _throwIfAsked();
    settings = TravelSettings(
      home: home,
      preference: settings?.preference ?? TravelPreference.auto,
      showInAgenda: settings?.showInAgenda ?? true,
    );
  }

  @override
  Future<void> deleteHome(String userId) async {
    _throwIfAsked();
    settings = null;
  }

  @override
  Future<void> savePreferences(
    String userId, {
    required TravelPreference preference,
    required bool showInAgenda,
  }) async {
    _throwIfAsked();
    final current = settings;
    if (current == null) return;
    settings = TravelSettings(
      home: current.home,
      preference: preference,
      showInAgenda: showInAgenda,
    );
  }

  @override
  Future<Map<String, TravelChoice>> fetchChoices(String userId) async =>
      Map.of(choices);

  @override
  Future<void> setChoice(String eventId, TravelChoice choice) async {
    _throwIfAsked();
    choices[eventId] = choice;
  }

  void _throwIfAsked() {
    final error = nextError;
    if (error == null) return;
    nextError = null;
    throw error;
  }
}

/// Recherche d'adresses sans réseau : rend les adresses dont le libellé
/// contient le texte tapé, situe les lieux connus de [places], et retient
/// chaque texte cherché.
class FakeAddressSearch implements AddressSearch {
  FakeAddressSearch([this.known = const [], this.places = const {}]);

  final List<Address> known;

  /// Le lieu de chaque texte de rdv reconnu ; un autre texte n'en a pas.
  final Map<String, Address> places;
  final searched = <String>[];
  AppException? nextError;

  @override
  Future<List<Address>> search(String text) async {
    searched.add(text);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final wanted = text.trim().toLowerCase();
    return known
        .where((address) => address.label.toLowerCase().contains(wanted))
        .toList();
  }

  @override
  Future<Address?> locate(String place) async => places[place.trim()];
}

/// Itinéraire sans réseau : une durée par mode, quels que soient les
/// points ; un mode absent n'a pas de chemin, un mode de [errors] échoue.
class FakeRouteTimes implements RouteTimes {
  FakeRouteTimes([this.durations = const {}, this.errors = const {}]);

  final Map<TravelMode, Duration> durations;
  final Map<TravelMode, AppException> errors;

  /// Chaque trajet demandé, dans l'ordre.
  final asked = <({GeoPoint from, GeoPoint to, TravelMode mode})>[];

  @override
  Future<Duration?> duration({
    required GeoPoint from,
    required GeoPoint to,
    required TravelMode mode,
  }) async {
    asked.add((from: from, to: to, mode: mode));
    if (errors[mode] case final error?) throw error;
    return durations[mode];
  }
}
