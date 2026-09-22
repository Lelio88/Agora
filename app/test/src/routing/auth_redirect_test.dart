import 'package:agora/src/routing/auth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = [
    // (connecté, emplacement, redirection attendue)
    (false, '/', '/sign-in'),
    (false, '/profile', '/sign-in'),
    (false, '/sign-in', null),
    (false, '/sign-up', null),
    (false, '/verify-email', null),
    (false, '/forgot-password', null),
    (false, '/reset-password', null),
    (true, '/', null),
    (true, '/profile', null),
    (true, '/sign-in', '/'),
    (true, '/sign-up', '/'),
    (true, '/verify-email', '/'),
    (true, '/forgot-password', '/'),
    // La vérification du code de réinitialisation ouvre une session avant
    // l'enregistrement du nouveau mot de passe : l'écran doit rester ouvert.
    (true, '/reset-password', null),
  ];

  for (final (signedIn, location, expected) in cases) {
    test(
      '${signedIn ? 'signed in' : 'signed out'} at $location → $expected',
      () {
        expect(
          authRedirect(isSignedIn: signedIn, location: location),
          expected,
        );
      },
    );
  }

  group('pending invitation', () {
    test('a signed-out visitor is sent to sign in', () {
      expect(
        authRedirect(isSignedIn: false, location: '/join/ABCD2345'),
        '/sign-in',
      );
    });

    test('once signed in, the visitor is brought back to the invitation', () {
      for (final location in ['/', '/sign-in', '/verify-email']) {
        expect(
          authRedirect(
            isSignedIn: true,
            location: location,
            pendingInvite: 'ABCD2345',
          ),
          '/join/ABCD2345',
          reason: location,
        );
      }
    });

    test('a pending invitation does not hijack other screens', () {
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/profile',
          pendingInvite: 'ABCD2345',
        ),
        isNull,
      );
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/join/ABCD2345',
          pendingInvite: 'ABCD2345',
        ),
        isNull,
      );
    });
  });

  test('inviteCodeInLocation reads only a plausible code', () {
    expect(inviteCodeInLocation('/join/abcd2345'), 'ABCD2345');
    expect(inviteCodeInLocation('/join/ABCD'), isNull);
    expect(inviteCodeInLocation('/join/ABCD2345/x'), isNull);
    expect(inviteCodeInLocation('/profile'), isNull);
  });
}
