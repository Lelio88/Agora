import 'package:agora/src/config/discord_bot.dart';
import 'package:agora/src/features/discord/data/supabase_discord_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discordDisplayName', () {
    test('prefers the global name Discord shows everywhere', () {
      expect(
        discordDisplayName({
          'name': 'zoe_42',
          'full_name': 'zoe_42',
          'custom_claims': {'global_name': 'Zoé'},
        }),
        'Zoé',
      );
    });

    test('falls back to the account name, then to a neutral label', () {
      expect(discordDisplayName({'name': 'zoe_42'}), 'zoe_42');
      expect(discordDisplayName({'custom_claims': 'unexpected'}), 'Discord');
      expect(discordDisplayName(null), 'Discord');
    });
  });

  group('discordBotInviteLink', () {
    test('asks only to see channels and write in them', () {
      final link = discordBotInviteLink('123456789012345678');

      expect(link?.host, 'discord.com');
      expect(link?.queryParameters['client_id'], '123456789012345678');
      expect(link?.queryParameters['scope'], 'bot applications.commands');
      expect(link?.queryParameters['permissions'], '3072');
    });

    test('offers nothing without a numeric application id', () {
      expect(discordBotInviteLink(''), isNull);
      expect(discordBotInviteLink('abc'), isNull);
    });
  });
}
