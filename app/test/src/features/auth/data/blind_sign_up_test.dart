import 'package:agora/src/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// L'inscription ne doit pas dire si une adresse a déjà un compte : GoTrue le
/// masque (utilisateur factice, sans identité), l'app ne doit pas le trahir.
void main() {
  User user({required List<UserIdentity> identities}) => User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-10-01T00:00:00Z',
    identities: identities,
  );

  final identity = UserIdentity(
    id: 'u1',
    userId: 'u1',
    identityData: const {},
    identityId: 'i1',
    provider: 'email',
    createdAt: '2026-10-01T00:00:00Z',
    lastSignInAt: '2026-10-01T00:00:00Z',
  );

  test('a brand-new address completes normally', () async {
    await expectLater(
      blindSignUp(() async => AuthResponse(user: user(identities: [identity]))),
      completes,
    );
  });

  test('an already-confirmed address completes exactly the same way', () async {
    // GoTrue, confirmation active : un utilisateur sans identité, aucun e-mail.
    await expectLater(
      blindSignUp(() async => AuthResponse(user: user(identities: const []))),
      completes,
    );
  });

  test('a server that names the duplicate gets the same answer', () async {
    // Confirmation coupée : GoTrue répond user_already_exists.
    await expectLater(
      blindSignUp(
        () => throw const AuthException(
          'User already registered',
          code: 'user_already_exists',
        ),
      ),
      completes,
    );
  });

  test('any other failure still surfaces', () async {
    await expectLater(
      blindSignUp(
        () => throw const AuthException('weak', code: 'weak_password'),
      ),
      throwsA(isA<AuthException>()),
    );
  });
}
