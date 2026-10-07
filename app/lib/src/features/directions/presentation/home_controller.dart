/// Contrôleur du domicile : le poser et l'effacer. Après chaque
/// changement, [homeProvider] est invalidé : « Moi » et « Y aller » suivent.
library;

import 'dart:async';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/directions/application/directions_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class HomeController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Pose [home] ; renvoie `true` en cas de succès.
  Future<bool> save(Address home) =>
      _change((repository, _) => repository.saveHome(home));

  /// Efface le domicile ; renvoie `true` en cas de succès.
  Future<bool> clear() =>
      _change((repository, userId) => repository.deleteHome(userId));

  Future<bool> _change(
    Future<void> Function(HomeRepository repository, String userId) change,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final userId = await ref.read(currentUserIdProvider.future);
      // Session expirée pendant que l'écran était ouvert : rien n'est
      // écrit, et l'écran ne doit pas annoncer le contraire.
      if (userId == null) throw const UnknownException();
      await change(ref.read(homeRepositoryProvider), userId);
    });
    if (!ref.mounted) return !result.hasError;
    state = result;
    if (!result.hasError) ref.invalidate(homeProvider);
    return !result.hasError;
  }
}

final homeControllerProvider =
    AsyncNotifierProvider.autoDispose<HomeController, void>(HomeController.new);
