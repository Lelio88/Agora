/// Providers du bot Discord : le compte relié, le salon de chaque groupe, et
/// le service qui les modifie.
///
/// Choix non évident : le compte se relit à chaque changement d'identité de
/// la session, car la liaison se termine hors de l'app (navigateur) et n'y
/// revient que par un évènement d'authentification.
library;

import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/discord/domain/discord.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final discordRepositoryProvider = Provider<DiscordRepository>(
  (ref) => throw UnimplementedError(
    'discordRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Le compte Discord relié, ou `null` ; aucun sans compte Agora.
final discordAccountProvider = StreamProvider<DiscordAccount?>((ref) async* {
  final repository = ref.watch(discordRepositoryProvider);
  if (await ref.watch(currentUserIdProvider.future) == null) {
    yield null;
    return;
  }
  yield await repository.fetchAccount();
  await for (final _ in repository.identityChanges()) {
    yield await repository.fetchAccount();
  }
});

/// Le salon relié à un groupe, ou `null`.
final discordChannelProvider = FutureProvider.autoDispose
    .family<DiscordChannel?, String>(
      (ref, groupId) =>
          ref.watch(discordRepositoryProvider).fetchChannel(groupId),
    );

final class DiscordService {
  const DiscordService(this._repository, this._invalidateChannel);

  final DiscordRepository _repository;
  final void Function(String groupId) _invalidateChannel;

  Future<bool> linkAccount() => _repository.linkAccount();

  Future<void> unlinkAccount() => _repository.unlinkAccount();

  Future<String> createLinkCode(String groupId) =>
      _repository.createLinkCode(groupId);

  Future<void> save(DiscordChannel channel) async {
    await _repository.saveChannel(channel);
    _invalidateChannel(channel.groupId);
  }

  Future<void> unlinkChannel(String groupId) async {
    await _repository.unlinkChannel(groupId);
    _invalidateChannel(groupId);
  }

  /// Relit le salon (après un `/relier` tapé dans Discord).
  void refresh(String groupId) => _invalidateChannel(groupId);
}

final discordServiceProvider = Provider<DiscordService>(
  (ref) => DiscordService(
    ref.watch(discordRepositoryProvider),
    (groupId) => ref.invalidate(discordChannelProvider(groupId)),
  ),
);
