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
}
