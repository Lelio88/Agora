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
  });
}
