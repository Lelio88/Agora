/// Providers des trajets : le domicile de l'utilisateur connecté et la
/// recherche d'adresses qui sert à le choisir.
///
/// Choix non évidents :
/// - [homeProvider] suit le compte connecté (`currentUserIdProvider`) : il
///   se vide à la déconnexion et se relit si le compte change, mais pas à
///   chaque rafraîchissement du jeton ;
/// - [addressSuggestionsProvider] ne relance pas une recherche ratée : la
///   frappe suivante en fera une autre, et le service de l'IGN limite les
///   appels par adresse IP.
library;

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/home_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => throw UnimplementedError(
    'homeRepositoryProvider must be overridden at the composition root.',
  ),
);

final addressSearchProvider = Provider<AddressSearch>(
  (ref) => throw UnimplementedError(
    'addressSearchProvider must be overridden at the composition root.',
  ),
);

/// Le domicile de l'utilisateur connecté, ou `null`.
final homeProvider = FutureProvider<Address?>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return null;
  return ref.watch(homeRepositoryProvider).fetchHome(userId);
});

/// Les adresses proposées pour un texte tapé.
final addressSuggestionsProvider = FutureProvider.autoDispose
    .family<List<Address>, String>(
      (ref, text) => ref.watch(addressSearchProvider).search(text),
      retry: (_, _) => null,
    );
