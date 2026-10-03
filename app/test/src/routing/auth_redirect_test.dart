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

  group('pending assistant consent', () {
    const consent = '/oauth/consent?authorization_id=abc12345xyz';

    test('a signed-out visitor on the consent screen is sent to sign in', () {
      expect(
        authRedirect(isSignedIn: false, location: '/oauth/consent'),
        '/sign-in',
      );
    });

    test('once signed in, the visitor is brought back to the request', () {
      for (final location in ['/', '/sign-in', '/verify-email']) {
        expect(
          authRedirect(
            isSignedIn: true,
            location: location,
            pendingConsent: 'abc12345xyz',
          ),
          consent,
          reason: location,
        );
      }
    });

    test('the assistant waiting comes before an invitation', () {
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/',
          pendingInvite: 'ABCD2345',
          pendingConsent: 'abc12345xyz',
        ),
        consent,
      );
    });

    test('a pending request does not hijack other screens', () {
      for (final location in ['/profile', '/oauth/consent']) {
        expect(
          authRedirect(
            isSignedIn: true,
            location: location,
            pendingConsent: 'abc12345xyz',
          ),
          isNull,
          reason: location,
        );
      }
    });
  });

  test('inviteCodeInLocation reads only a plausible code', () {
    expect(inviteCodeInLocation('/join/abcd2345'), 'ABCD2345');
    expect(inviteCodeInLocation('/join/ABCD'), isNull);
    expect(inviteCodeInLocation('/join/ABCD2345/x'), isNull);
    expect(inviteCodeInLocation('/profile'), isNull);
  });

  group('inviteRouteFromAppLink', () {
    test('turns an invitation link opened in the app into its screen', () {
      // Android transmet le lien avec son fragment : « #/join/CODE ».
      expect(
        inviteRouteFromAppLink(
          Uri.parse('https://agora.heianenterprise.com/#/join/abcd2345'),
        ),
        '/join/ABCD2345',
      );
      expect(
        inviteRouteFromAppLink(Uri.parse('/#/join/ABCD2345')),
        '/join/ABCD2345',
      );
    });

    test('leaves every other location alone', () {
      expect(inviteRouteFromAppLink(Uri.parse('/join/ABCD2345')), isNull);
      expect(inviteRouteFromAppLink(Uri.parse('/#/profile')), isNull);
      expect(inviteRouteFromAppLink(Uri.parse('/#/join/ABCD')), isNull);
      expect(
        inviteRouteFromAppLink(Uri.parse('/groups/g#/join/ABCD2345')),
        isNull,
      );
      expect(inviteRouteFromAppLink(Uri.parse('/')), isNull);
    });
  });
}
