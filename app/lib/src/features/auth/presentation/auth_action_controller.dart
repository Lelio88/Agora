/// Contrôleur commun aux écrans de compte : exécute une action du dépôt et
/// expose son état (chargement, puis succès ou erreur typée).
///
/// Un provider par action, pour que deux boutons d'un même écran (« Valider »
/// et « Renvoyer le code ») aient chacun leur état de chargement. Tous sont
/// `autoDispose` : l'erreur d'un écran disparaît quand on le quitte.
///
/// Invariant : l'état n'est écrit qu'après avoir vérifié `ref.mounted`.
/// Réussir une connexion fait quitter l'écran (redirection du routeur), donc
/// disposer le contrôleur pendant l'`await`.
library;

import 'dart:async';

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AuthActionController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Exécute [action] ; renvoie `true` si elle a réussi.
  Future<bool> run(Future<void> Function(AuthRepository auth) action) async {
    final auth = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => action(auth));
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}

AsyncNotifierProvider<AuthActionController, void> _action() =>
    AsyncNotifierProvider.autoDispose<AuthActionController, void>(
      AuthActionController.new,
    );

final signInActionProvider = _action();
final signUpActionProvider = _action();
final verifyCodeActionProvider = _action();
final resendCodeActionProvider = _action();
final requestResetActionProvider = _action();
final resetPasswordActionProvider = _action();
