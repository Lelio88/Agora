/// Providers du profil. [currentProfileProvider] suit la session : il se vide
/// à la déconnexion et se recharge à la connexion suivante.
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
  return ref.watch(profileRepositoryProvider).fetchProfile(user.id);
});
