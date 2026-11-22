import 'package:agora/src/supabase/oauth_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('webReturnAddress', () {
    test('keeps the page, without the routing fragment', () {
      expect(
        webReturnAddress(Uri.parse('https://agora.test/#/profile')).toString(),
        'https://agora.test/',
      );
    });

    test('keeps an assistant request waiting for consent', () {
      expect(
        webReturnAddress(
          Uri.parse(
            'https://agora.test/oauth/consent?authorization_id=abc12345xyz#/sign-in',
          ),
        ).toString(),
        'https://agora.test/oauth/consent?authorization_id=abc12345xyz',
      );
    });

    test('drops what a previous OAuth return left behind', () {
      expect(
        webReturnAddress(
          Uri.parse(
            'http://127.0.0.1:3000/oauth/consent?authorization_id=abc12345xyz&code=old&state=s',
          ),
        ).toString(),
        'http://127.0.0.1:3000/oauth/consent?authorization_id=abc12345xyz',
      );
      expect(
        webReturnAddress(
          Uri.parse(
            'https://agora.test/?error=access_denied&error_description=x',
          ),
        ).toString(),
        'https://agora.test/',
      );
    });

    test('carries a link waiting for the sign-in across the reload', () {
      final back = webReturnAddress(
        Uri.parse('https://agora.test/#/sign-in'),
        resume: '/join/ABCD2345',
      );
      expect(back.queryParameters, {'resume': '/join/ABCD2345'});
      expect(back.path, '/');
      expect(back.fragment, isEmpty);
      expect(resumeIn(back), '/join/ABCD2345');
    });

    test('drops the link a previous return carried', () {
      expect(
        webReturnAddress(
          Uri.parse('https://agora.test/?resume=%2Fjoin%2FABCD2345&code=old'),
        ).toString(),
        'https://agora.test/',
      );
    });
  });

  test('withoutResume leaves the rest of the page, OAuth code included', () {
    expect(
      withoutResume(
        Uri.parse('https://agora.test/?code=c&resume=%2Fjoin%2FABCD2345#/x'),
      ).toString(),
      'https://agora.test/?code=c#/x',
    );
    expect(withoutResume(Uri.parse('https://agora.test/#/x')), isNull);
  });
}
