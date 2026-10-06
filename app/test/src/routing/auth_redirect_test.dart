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

  group('appLinkRoute', () {
    test('turns an invitation link opened in the app into its screen', () {
      // Android transmet le lien avec son fragment : « #/join/CODE ».
      expect(
        appLinkRoute(
          Uri.parse('https://agora.heianenterprise.com/#/join/abcd2345'),
        ),
        '/join/ABCD2345',
      );
      expect(appLinkRoute(Uri.parse('/#/join/ABCD2345')), '/join/ABCD2345');
    });

    test('leaves every other location alone', () {
      expect(appLinkRoute(Uri.parse('/join/ABCD2345')), isNull);
      expect(appLinkRoute(Uri.parse('/#/profile')), isNull);
      expect(appLinkRoute(Uri.parse('/#/join/ABCD')), isNull);
      expect(appLinkRoute(Uri.parse('/groups/g#/join/ABCD2345')), isNull);
      expect(appLinkRoute(Uri.parse('/')), isNull);
    });

    test('turns a twin link opened in the app into its screen', () {
      // Arpente propose un jumelage : « #/twin?de=…&code=…&etat=… ».
      expect(
        appLinkRoute(
          Uri.parse(
            'https://agora.heianenterprise.com/'
            '#/twin?de=arpente&code=ABC234&nom=Sortie+Caen&etat=abcdefghijklmnop',
          ),
        ),
        '/twin?de=arpente&code=ABC234&nom=Sortie+Caen&etat=abcdefghijklmnop',
      );
      expect(appLinkRoute(Uri.parse('/#/twin')), '/twin');
    });

    test('follows no other twin-like location', () {
      expect(appLinkRoute(Uri.parse('/#/twins?de=arpente')), isNull);
      expect(appLinkRoute(Uri.parse('/#/twin/x?de=arpente')), isNull);
      expect(appLinkRoute(Uri.parse('/groups/g#/twin?de=arpente')), isNull);
    });

    test('turns a rdv link opened in the app into its screen', () {
      // Arpente prépare un rdv : « #/event?de=…&titre=…&debut=… ».
      expect(
        appLinkRoute(
          Uri.parse(
            'https://agora.heianenterprise.com/'
            '#/event?de=arpente&titre=Sortie&debut=2026-10-10T12:00:00Z&duree=90',
          ),
        ),
        '/event?de=arpente&titre=Sortie&debut=2026-10-10T12:00:00Z&duree=90',
      );
      expect(appLinkRoute(Uri.parse('/#/events?de=arpente')), isNull);
    });
  });

  group('pending twin link', () {
    const twin = '/twin?de=arpente&code=ABC234&etat=abcdefghijklmnop';

    test('once signed in, the visitor is brought back to the twin link', () {
      for (final location in ['/', '/sign-in', '/verify-email']) {
        expect(
          authRedirect(isSignedIn: true, location: location, pendingTwin: twin),
          twin,
          reason: location,
        );
      }
    });

    test('an assistant request and an invitation come first', () {
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/',
          pendingInvite: 'ABCD2345',
          pendingTwin: twin,
        ),
        '/join/ABCD2345',
      );
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/',
          pendingConsent: 'abc12345xyz',
          pendingTwin: twin,
        ),
        '/oauth/consent?authorization_id=abc12345xyz',
      );
    });

    test('a pending twin link does not hijack other screens', () {
      for (final location in ['/profile', '/twin']) {
        expect(
          authRedirect(isSignedIn: true, location: location, pendingTwin: twin),
          isNull,
          reason: location,
        );
      }
    });
  });

  group('pending rdv link', () {
    const event = '/event?de=arpente&titre=Sortie&duree=90';

    test('once signed in, the visitor is brought back to the rdv link', () {
      for (final location in ['/', '/sign-in']) {
        expect(
          authRedirect(
            isSignedIn: true,
            location: location,
            pendingEvent: event,
          ),
          event,
          reason: location,
        );
      }
    });

    test('a twin link comes first, and other screens are left alone', () {
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/',
          pendingTwin: '/twin?de=arpente',
          pendingEvent: event,
        ),
        '/twin?de=arpente',
      );
      expect(
        authRedirect(
          isSignedIn: true,
          location: '/profile',
          pendingEvent: event,
        ),
        isNull,
      );
    });
  });
}
