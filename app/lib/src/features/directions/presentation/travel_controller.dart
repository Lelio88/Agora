/// Contrôleur des trajets : poser ou effacer le domicile, régler le mode et
/// l'affichage dans l'agenda, choisir le mode d'un rdv. Après chaque
/// changement, le provider lu est invalidé : « Moi », « Y aller », les
/// fiches et l'agenda suivent.
library;

import 'dart:async';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/directions/application/directions_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/domain/travel_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

final class TravelController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Pose [home] ; renvoie `true` en cas de succès.
  Future<bool> saveHome(Address home) => _change(
    travelSettingsProvider,
    (repository, _) => repository.saveHome(home),
  );

  /// Efface le domicile ; renvoie `true` en cas de succès.
  Future<bool> clearHome() => _change(
    travelSettingsProvider,
    (repository, userId) => repository.deleteHome(userId),
  );

  /// Règle le mode préféré et l'affichage dans l'agenda.
  Future<bool> savePreferences({
    required TravelPreference preference,
    required bool showInAgenda,
  }) => _change(
    travelSettingsProvider,
    (repository, userId) => repository.savePreferences(
      userId,
      preference: preference,
      showInAgenda: showInAgenda,
    ),
  );

  /// Choisit le mode de [eventKey] (un rdv, ou le rdv maître d'une série).
  Future<bool> choose(String eventKey, TravelChoice choice) => _change(
    travelChoicesProvider,
    (repository, _) => repository.setChoice(eventKey, choice),
  );

  Future<bool> _change(
    ProviderOrFamily changed,
    Future<void> Function(TravelRepository repository, String userId) change,
  ) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final userId = await ref.read(currentUserIdProvider.future);
      // Session expirée pendant que l'écran était ouvert : rien n'est
      // écrit, et l'écran ne doit pas annoncer le contraire.
      if (userId == null) throw const UnknownException();
      await change(ref.read(travelRepositoryProvider), userId);
    });
    if (!ref.mounted) return !result.hasError;
    state = result;
    if (!result.hasError) ref.invalidate(changed);
    return !result.hasError;
  }
}

final travelControllerProvider =
    AsyncNotifierProvider.autoDispose<TravelController, void>(
      TravelController.new,
    );
