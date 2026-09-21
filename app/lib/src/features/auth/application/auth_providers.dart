/// Providers de l'authentification. Le dépôt est déclaré ici sans
/// implémentation : la composition root le branche.
library;

import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Utilisateur connecté, ou `null` ; se met à jour à chaque connexion et
/// déconnexion.
final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchCurrentUser(),
);
