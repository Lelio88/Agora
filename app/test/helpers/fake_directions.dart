import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/home_repository.dart';

/// Domicile en mémoire, une valeur par utilisateur comme la table
/// `travel_settings`.
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({this.home});

  /// Le domicile enregistré, tel que l'écran l'a laissé.
  Address? home;

  AppException? nextError;

  @override
  Future<Address?> fetchHome(String userId) async => home;

  @override
  Future<void> saveHome(Address home) async {
    _throwIfAsked();
    this.home = home;
  }

  @override
  Future<void> deleteHome(String userId) async {
    _throwIfAsked();
    home = null;
  }

  void _throwIfAsked() {
    final error = nextError;
    if (error == null) return;
    nextError = null;
    throw error;
  }
}

/// Recherche d'adresses sans réseau : rend les adresses dont le libellé
/// contient le texte tapé, et retient chaque texte cherché.
class FakeAddressSearch implements AddressSearch {
  FakeAddressSearch([this.known = const []]);

  final List<Address> known;
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
}
