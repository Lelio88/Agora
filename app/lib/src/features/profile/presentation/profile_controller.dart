/// Contrôleur de l'écran de profil : enregistrement, déconnexion et
/// suppression du compte.
///
/// Après un enregistrement, [currentProfileProvider] est invalidé : la langue
/// de toute l'app suit alors le profil sans redémarrage.
library;

import 'dart:async';

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/profile/application/profile_providers.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class ProfileController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Enregistre [profile] ; renvoie `true` en cas de succès.
  Future<bool> save(Profile profile) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).updateProfile(profile),
    );
    if (!ref.mounted) return !result.hasError;
    state = result;
    if (!result.hasError) ref.invalidate(currentProfileProvider);
    return !result.hasError;
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
    if (ref.mounted) state = result;
  }

  /// Supprime le compte ; renvoie `true` en cas de succès. La session se
  /// ferme, et le routeur quitte l'écran pendant l'`await` : l'état n'est
  /// écrit que si le contrôleur est encore monté.
  Future<bool> deleteAccount() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).deleteAccount(),
    );
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}

final profileControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, void>(
      ProfileController.new,
    );
