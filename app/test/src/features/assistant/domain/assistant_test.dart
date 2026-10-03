import 'package:agora/src/features/assistant/application/assistant_providers.dart';
import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recognizeAssistant', () {
    final cases = <(String, KnownAssistant?)>[
      ('https://claude.ai/api/mcp/auth_callback', KnownAssistant.claude),
      (
        'https://claude.com/api/mcp/auth_callback?code=x',
        KnownAssistant.claude,
      ),
      (
        'https://chatgpt.com/connector_platform_oauth_redirect',
        KnownAssistant.chatGpt,
      ),
      ('https://chatgpt.com/connector/oauth/abc123', KnownAssistant.chatGpt),
      ('https://vscode.dev/redirect', KnownAssistant.vsCode),
      ('cursor://anysphere.cursor-mcp/oauth/callback', KnownAssistant.cursor),
      ('http://localhost:53682/callback', KnownAssistant.localTool),
      ('http://127.0.0.1:33418/', KnownAssistant.localTool),
      ('http://[::1]:8080/oauth', KnownAssistant.localTool),
      // Le chemin compte : un domaine seul laisserait passer ses redirections.
      ('https://claude.ai/autre/chemin', null),
      ('https://claude.ai.evil.com/api/mcp/auth_callback', null),
      ('http://claude.ai/api/mcp/auth_callback', null),
      ('https://claude.ai:8443/api/mcp/auth_callback', null),
      ('https://evil@claude.ai/api/mcp/auth_callback', null),
      ('https://claude.ai/api/mcp/auth_callback#x', null),
      ('http://localhost.evil.com/callback', null),
      ('https://localhost/callback', null),
      ('javascript:alert(1)', null),
      ('cursor://autre/oauth/callback', null),
      ('', null),
    ];
    for (final (uri, expected) in cases) {
      test('$uri → $expected', () => expect(recognizeAssistant(uri), expected));
    }
  });

  group('consentRequestIn', () {
    test('reads the request on the consent path', () {
      expect(
        consentRequestIn(
          Uri.parse(
            'https://agora.test/oauth/consent?authorization_id=abc12345xyz',
          ),
        ),
        'abc12345xyz',
      );
    });

    test('ignores other pages and implausible identifiers', () {
      for (final uri in [
        'https://agora.test/?authorization_id=abc12345xyz',
        'https://agora.test/oauth/consent',
        'https://agora.test/oauth/consent?authorization_id=<script>',
        'https://agora.test/oauth/consent?authorization_id=abc',
      ]) {
        expect(consentRequestIn(Uri.parse(uri)), isNull, reason: uri);
      }
    });
  });

  test('the connector address is the API followed by /mcp', () {
    expect(
      mcpUrlFor(Uri.parse('https://api.agora.test')).toString(),
      'https://api.agora.test/mcp',
    );
    expect(
      mcpUrlFor(Uri.parse('http://127.0.0.1:55321/')).toString(),
      'http://127.0.0.1:55321/mcp',
    );
    expect(
      claudeCodeCommand(Uri.parse('https://api.agora.test/mcp')),
      'claude mcp add --transport http --scope user agora https://api.agora.test/mcp',
    );
  });
}
