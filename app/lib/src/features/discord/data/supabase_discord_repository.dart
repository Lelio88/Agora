/// [DiscordRepository] sur GoTrue (identité Discord) et PostgREST (salon).
///
/// Choix non évidents :
/// - la liaison du compte passe par `linkIdentity` (OAuth, flux PKCE) : sur
///   Android, Discord renvoie vers `app.agora://login-callback`, que le
///   manifeste déclare et que supabase_flutter intercepte ; sur le web, vers
///   la page courante ;
/// - le compte se relit par `getUserIdentities` (et non dans la session en
///   cache) : juste après le retour d'OAuth, la session peut encore dater
///   d'avant la liaison ;
/// - les réglages du salon s'écrivent par un PATCH des seules colonnes
///   ouvertes à `authenticated` ; la RLS réserve l'écriture aux admins.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:agora/src/features/auth/data/auth_error_translator.dart';
import 'package:agora/src/features/discord/domain/discord.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Retour d'OAuth sur Android (déclaré dans AndroidManifest.xml).
const androidAuthCallback = 'app.agora://login-callback';

final class SupabaseDiscordRepository implements DiscordRepository {
  const SupabaseDiscordRepository(this._client);

  final SupabaseClient _client;

  Future<UserIdentity?> _discordIdentity() async {
    final identities = await _client.auth.getUserIdentities();
    return identities.where((i) => i.provider == 'discord').firstOrNull;
  }

  @override
  Future<DiscordAccount?> fetchAccount() => _guardAuth(() async {
    final identity = await _discordIdentity();
    if (identity == null) return null;
    return DiscordAccount(name: discordDisplayName(identity.identityData));
  });

  @override
  Stream<void> identityChanges() => _client.auth.onAuthStateChange
      .where(
        (state) =>
            state.event == AuthChangeEvent.userUpdated ||
            state.event == AuthChangeEvent.signedIn,
      )
      .map((_) {});

  @override
  Future<bool> linkAccount() => _guardAuth(
    () => _client.auth.linkIdentity(
      OAuthProvider.discord,
      redirectTo: kIsWeb
          ? Uri.base.removeFragment().toString()
          : androidAuthCallback,
      // L'identité seule : ni serveurs, ni messages.
      scopes: 'identify',
    ),
  );

  @override
  Future<void> unlinkAccount() => _guardAuth(() async {
    final identity = await _discordIdentity();
    if (identity != null) await _client.auth.unlinkIdentity(identity);
  });

  @override
  Future<DiscordChannel?> fetchChannel(String groupId) =>
      guardPostgrest(() async {
        final row = await _client
            .from('discord_channels')
            .select(
              'group_id, channel_name, timezone, recap, recap_weekday, '
              'recap_hour, '
              'reminder_minutes',
            )
            .eq('group_id', groupId)
            .maybeSingle();
        if (row == null) return null;
        return DiscordChannel(
          groupId: row['group_id'] as String,
          channelName: row['channel_name'] as String? ?? '',
          timezone: row['timezone'] as String,
          recap: DiscordRecap.fromCode(row['recap'] as String?),
          recapWeekday: row['recap_weekday'] as int,
          recapHour: row['recap_hour'] as int,
          reminderMinutes: row['reminder_minutes'] as int?,
        );
      });

  @override
  Future<String> createLinkCode(String groupId) => guardPostgrest(
    () async => await _client.rpc<String>(
      'create_discord_link_code',
      params: {'p_group_id': groupId},
    ),
  );

  @override
  Future<void> saveChannel(DiscordChannel channel) => guardPostgrest(
    () => _client
        .from('discord_channels')
        .update({
          'recap': channel.recap.code,
          'recap_weekday': channel.recapWeekday,
          'recap_hour': channel.recapHour,
          'reminder_minutes': channel.reminderMinutes,
        })
        .eq('group_id', channel.groupId),
  );

  @override
  Future<void> unlinkChannel(String groupId) => guardPostgrest(
    () => _client.from('discord_channels').delete().eq('group_id', groupId),
  );
}

/// Nom à afficher d'une identité Discord : le nom global s'il existe, sinon
/// l'identifiant du compte.
String discordDisplayName(Map<String, dynamic>? data) {
  final claims = data?['custom_claims'];
  final global = claims is Map ? claims['global_name'] : null;
  for (final candidate in [global, data?['full_name'], data?['name']]) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
  }
  return 'Discord';
}

Future<T> _guardAuth<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on AuthException catch (error) {
    if (error.code == 'identity_already_exists') {
      throw const DiscordAlreadyLinkedException();
    }
    throw translateAuthError(error);
  } on Exception catch (error) {
    throw looksLikeNetworkError(error.toString())
        ? const NetworkException()
        : const UnknownException();
  }
}
