/// Le domicile de l'utilisateur connecté : le départ par défaut de « Y
/// aller », gardé sur le compte (table `travel_settings`).
///
/// Invariants : lisible et modifiable par sa seule personne (RLS) ; seules
/// des `AppException` en sortent ; pas de domicile n'est pas une erreur,
/// c'est `null`.
library;

import 'package:agora/src/features/directions/domain/address.dart';

abstract interface class HomeRepository {
  /// Le domicile de [userId], ou `null` s'il n'en a pas posé.
  Future<Address?> fetchHome(String userId);

  /// Pose ou remplace le domicile de l'utilisateur connecté.
  Future<void> saveHome(Address home);

  /// Efface le domicile de [userId].
  Future<void> deleteHome(String userId);
}
