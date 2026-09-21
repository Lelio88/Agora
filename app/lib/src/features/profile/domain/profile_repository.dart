/// Lecture et modification du profil de l'utilisateur connecté.
///
/// Invariant : seules les erreurs `AppException` en sortent. Un fuseau refusé
/// par le serveur devient `InvalidTimezoneException`.
library;

import 'package:agora/src/features/profile/domain/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> fetchProfile(String userId);

  /// Enregistre le nom, la langue et le fuseau de [profile].
  Future<void> updateProfile(Profile profile);
}
