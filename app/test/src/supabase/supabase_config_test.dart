import 'package:agora/src/supabase/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseConfig.parse', () {
    test('accepts an https URL with a key', () {
      final config = SupabaseConfig.parse(
        url: 'https://api.agora.heianenterprise.com',
        publishableKey: 'publishable-key',
      );

      expect(config.url, 'https://api.agora.heianenterprise.com');
      expect(config.publishableKey, 'publishable-key');
    });

    test('accepts plain http only for a local host', () {
      for (final host in ['127.0.0.1', 'localhost', '10.0.2.2']) {
        final config = SupabaseConfig.parse(
          url: 'http://$host:55321',
          publishableKey: 'publishable-key',
        );
        expect(config.url, 'http://$host:55321');
      }
    });

    test('rejects plain http for a remote host', () {
      expect(
        () => SupabaseConfig.parse(
          url: 'http://api.agora.heianenterprise.com',
          publishableKey: 'publishable-key',
        ),
        throwsStateError,
      );
    });

    test('rejects a URL given without its key', () {
      expect(
        () => SupabaseConfig.parse(
          url: 'https://api.agora.heianenterprise.com',
          publishableKey: '',
        ),
        throwsStateError,
      );
    });

    test('rejects a key given without its URL', () {
      expect(
        () => SupabaseConfig.parse(url: '', publishableKey: 'publishable-key'),
        throwsStateError,
      );
    });

    test('rejects a malformed URL', () {
      expect(
        () => SupabaseConfig.parse(
          url: 'not a url',
          publishableKey: 'publishable-key',
        ),
        throwsStateError,
      );
    });
  });
}
