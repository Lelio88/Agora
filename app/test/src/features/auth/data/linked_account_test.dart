import 'package:agora/src/features/auth/data/supabase_auth_repository.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

UserIdentity _identity(String provider, Map<String, dynamic>? data) =>
    UserIdentity(
      id: '$provider-id',
      userId: 'user-1',
      identityData: data,
      identityId: '$provider-identity',
      provider: provider,
      createdAt: null,
      lastSignInAt: null,
    );

void main() {
  group('linkedAccountFrom', () {
    test('names the Google account by its address', () {
      final account = linkedAccountFrom([
        _identity('email', {'email': 'zoe@test.local'}),
        _identity('google', {'email': 'zoe@gmail.com', 'name': 'Zoé'}),
      ], SocialProvider.google);

      expect(account?.label, 'zoe@gmail.com');
      expect(account?.isOnlyWayIn, isFalse);
    });

    test('flags the only identity: GoTrue would refuse to unlink it', () {
      final account = linkedAccountFrom([
        _identity('google', {'email': 'zoe@gmail.com'}),
      ], SocialProvider.google);

      expect(account?.isOnlyWayIn, isTrue);
    });

    test('falls back to the name, then to the provider', () {
      expect(
        linkedAccountFrom([
          _identity('google', {'name': 'Zoé'}),
        ], SocialProvider.google)?.label,
        'Zoé',
      );
      expect(
        linkedAccountFrom([
          _identity('google', null),
        ], SocialProvider.google)?.label,
        'Google',
      );
    });

    test('is null without an identity from that provider', () {
      expect(
        linkedAccountFrom([
          _identity('discord', {'name': 'zoe'}),
        ], SocialProvider.google),
        isNull,
      );
    });
  });
}
