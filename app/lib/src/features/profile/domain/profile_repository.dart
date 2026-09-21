/// Lecture et modification du profil de l'utilisateur connecté.
///
/// Invariant : seules les erreurs `AppException` en sortent. Un fuseau refusé
/// par le serveur devient `InvalidTimezoneException`. Un profil absent n'est
/// pas une erreur : c'est `null` (compte supprimé, voir
/// `currentProfileProvider`).
library;

import 'package:agora/src/features/profile/domain/profile.dart';

abstract interface class ProfileRepository {
  /// Profil de [userId], ou `null` s'il n'existe plus.
  Future<Profile?> fetchProfile(String userId);

  /// Enregistre le nom, la langue et le fuseau de [profile].
  Future<void> updateProfile(Profile profile);
}
