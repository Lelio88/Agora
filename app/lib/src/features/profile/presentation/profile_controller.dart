/// Contrôleur de l'écran de profil : enregistrement et déconnexion.
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
}

final profileControllerProvider =
    AsyncNotifierProvider.autoDispose<ProfileController, void>(
      ProfileController.new,
    );
