/// Providers de l'authentification. Le dépôt est déclaré ici sans
/// implémentation : la composition root le branche.
library;

import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/auth_repository.dart';
import 'package:agora/src/features/auth/domain/left_behind_event.dart';
import 'package:agora/src/features/auth/domain/linked_account.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Ce qu'une suppression de compte laisserait derrière elle. Relu à chaque
/// ouverture du dialogue de suppression : un rdv a pu être proposé depuis.
final proposedGroupEventsProvider =
    FutureProvider.autoDispose<List<LeftBehindEvent>>(
      (ref) => ref.watch(authRepositoryProvider).proposedGroupEvents(),
    );

/// Utilisateur connecté, ou `null` ; se met à jour à chaque connexion et
/// déconnexion.
final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchCurrentUser(),
);

/// Identifiant du compte connecté, ou `null` déconnecté ; en attente tant
/// que la session n'est pas connue.
///
/// Les providers de données propres à un compte (agendas, groupes, flux
/// temps réel) regardent son `.future` : changer de compte dans la même
/// session les recharge, au lieu de servir ce qui avait été lu pour le
/// compte précédent (ou pour une session périmée au chargement). Le même
/// compte réémis (rafraîchissement du jeton) ne recharge rien : la valeur
/// n'a pas changé.
final currentUserIdProvider = FutureProvider<String?>(
  (ref) async => (await ref.watch(currentUserProvider.future))?.id,
);

/// Le compte de [SocialProvider] relié à celui-ci, ou `null` ; aucun sans
/// compte Agora. Relu à chaque changement d'identité : une liaison se
/// termine hors de l'app (navigateur) et n'y revient que par un évènement
/// d'authentification.
final linkedAccountProvider =
    StreamProvider.family<LinkedAccount?, SocialProvider>((
      ref,
      provider,
    ) async* {
      final repository = ref.watch(authRepositoryProvider);
      if (await ref.watch(currentUserIdProvider.future) == null) {
        yield null;
        return;
      }
      yield await repository.linkedAccount(provider);
      await for (final _ in repository.identityChanges()) {
        yield await repository.linkedAccount(provider);
      }
    });
