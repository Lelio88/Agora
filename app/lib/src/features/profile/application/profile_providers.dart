/// Providers du profil. [currentProfileProvider] suit la session : il se vide
/// à la déconnexion et se recharge à la connexion suivante.
///
/// Choix non évident : un utilisateur connecté **sans profil** est une
/// session orpheline, et le provider la ferme. Cela arrive quand le compte a
/// été supprimé ailleurs (un autre appareil) : le jeton d'accès reste valide
/// jusqu'à son expiration, et l'app se croirait connectée à un compte qui
/// n'existe plus. Le trigger d'inscription crée le profil dans la même
/// transaction que le compte : un profil absent ne peut pas être un retard.
library;

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:agora/src/features/profile/domain/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw UnimplementedError(
    'profileRepositoryProvider must be overridden at the composition root.',
  ),
);

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return null;
  final profile = await ref
      .watch(profileRepositoryProvider)
      .fetchProfile(user.id);
  if (profile == null) await ref.read(authRepositoryProvider).signOut();
  return profile;
});
