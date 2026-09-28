import 'dart:async';

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/discord/domain/discord.dart';

/// Faux [DiscordRepository] en mémoire. La liaison du compte se termine
/// hors de l'app : [completeLink] joue le retour d'OAuth, comme GoTrue le
/// ferait en changeant la session.
class FakeDiscordRepository implements DiscordRepository {
  DiscordAccount? account;
  final channels = <String, DiscordChannel>{};
  final calls = <String>[];
  AppException? nextError;
  bool linkOpens = true;
  final _identity = StreamController<void>.broadcast();

  void _record(String call) {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  /// Le retour de Discord : le compte est relié, la session le signale.
  void completeLink(String name) {
    account = DiscordAccount(name: name);
    _identity.add(null);
  }

  /// La commande `/relier` tapée dans Discord.
  void linkChannelFromDiscord(String groupId, String name) =>
      channels[groupId] = DiscordChannel(
        groupId: groupId,
        channelName: name,
        timezone: 'Europe/Paris',
        recap: DiscordRecap.weekly,
        recapWeekday: 1,
        recapHour: 8,
      );

  Future<void> dispose() => _identity.close();

  @override
  Future<DiscordAccount?> fetchAccount() async {
    _record('fetchAccount');
    return account;
  }

  @override
  Stream<void> identityChanges() => _identity.stream;

  @override
  Future<bool> linkAccount() async {
    _record('linkAccount');
    return linkOpens;
  }

  @override
  Future<void> unlinkAccount() async {
    _record('unlinkAccount');
    account = null;
  }

  @override
  Future<DiscordChannel?> fetchChannel(String groupId) async {
    _record('fetchChannel');
    return channels[groupId];
  }

  @override
  Future<String> createLinkCode(String groupId) async {
    _record('createLinkCode');
    return 'K7PQ2MXA';
  }

  @override
  Future<void> saveChannel(DiscordChannel channel) async {
    _record('saveChannel');
    channels[channel.groupId] = channel;
  }

  @override
  Future<void> unlinkChannel(String groupId) async {
    _record('unlinkChannel');
    channels.remove(groupId);
  }
}
