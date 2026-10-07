/// Les réglages de trajet de l'utilisateur connecté : son domicile, le mode
/// préféré, l'affichage dans l'agenda (table `travel_settings`), et le mode
/// choisi pour tel rdv (table `event_travel_modes`).
///
/// Invariants : lisibles et modifiables par leur seule personne (RLS) ;
/// seules des `AppException` en sortent ; pas de domicile n'est pas une
/// erreur, c'est `null`. Un choix vise un rdv, ou une série entière par
/// l'identifiant de son rdv maître.
library;

import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';

abstract interface class TravelRepository {
  /// Les réglages de [userId], ou `null` s'il n'a pas posé de domicile.
  Future<TravelSettings?> fetchSettings(String userId);

  /// Pose ou remplace le domicile de l'utilisateur connecté, sans toucher
  /// à ses autres réglages.
  Future<void> saveHome(Address home);

  /// Efface le domicile de [userId], et ses réglages avec lui.
  Future<void> deleteHome(String userId);

  /// Le mode préféré et l'affichage dans l'agenda de [userId], qui a un
  /// domicile.
  Future<void> savePreferences(
    String userId, {
    required TravelPreference preference,
    required bool showInAgenda,
  });

  /// Les modes choisis par [userId], par identifiant de rdv.
  Future<Map<String, TravelChoice>> fetchChoices(String userId);

  /// Pose le mode de [eventId] pour l'utilisateur connecté.
  Future<void> setChoice(String eventId, TravelChoice choice);
}
