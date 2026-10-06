import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:agora/src/features/assistant/presentation/assistant_keys.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_assistant_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

const _request = 'abc12345xyz';
final _mcp = Uri.parse('https://api.agora.test/mcp');

void main() {
  group('consent screen', () {
    testWidgets(
      'a request waits through sign-in, then hands the code back to Claude',
      (tester) async {
        final robot = AgoraRobot(tester);
        final assistant = FakeAssistantRepository()..seedRequest(_request);
        await robot.pumpApp(assistant: assistant, pendingConsent: _request);
        robot.expectScreen(AuthKeys.signInScreen);

        await robot.signIn('zoe@test.local', 'motdepasse1');
        robot.expectScreen(ConsentKeys.screen);
        robot.expectText('Autoriser Claude à accéder à ton agenda Agora ?');
        robot.expectText('Compte : zoe@test.local');

        await robot.tap(ConsentKeys.approve);
        expect(assistant.calls, contains('approve $_request'));
        expect(
          robot.links.openedInPlace.single.toString(),
          'https://claude.ai/api/mcp/auth_callback?code=code-$_request',
        );
        expect(find.byKey(ConsentKeys.handedOver), findsOneWidget);
        expect(robot.logger.errorCount, 0);
      },
    );

    testWidgets('a signed-in visitor lands on the request at once', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      final assistant = FakeAssistantRepository()
        ..seedRequest(_request, redirectUri: 'http://127.0.0.1:53682/callback');
      await robot.pumpApp(
        auth: _signedIn(),
        assistant: assistant,
        pendingConsent: _request,
      );
      robot.expectScreen(ConsentKeys.screen);
      expect(find.textContaining('un outil de cet ordinateur'), findsOneWidget);

      await robot.tap(ConsentKeys.deny);
      expect(assistant.calls, contains('deny $_request'));
      expect(
        robot.links.openedInPlace.single.queryParameters['error'],
        'access_denied',
      );
    });

    testWidgets(
      'an unknown assistant is refused without following its address',
      (tester) async {
        final robot = AgoraRobot(tester);
        final assistant = FakeAssistantRepository()
          ..seedRequest(
            _request,
            redirectUri: 'https://evil.example/callback',
            clientName: 'Claude',
          );
        await robot.pumpApp(
          auth: _signedIn(),
          assistant: assistant,
          pendingConsent: _request,
        );

        expect(assistant.calls, contains('deny $_request'));
        expect(find.byKey(ConsentKeys.refused), findsOneWidget);
        expect(find.textContaining('evil.example'), findsOneWidget);
        expect(find.byKey(ConsentKeys.approve), findsNothing);
        expect(robot.links.openedInPlace, isEmpty);
      },
    );

    testWidgets('an access already granted goes straight back', (tester) async {
      final robot = AgoraRobot(tester);
      final assistant = FakeAssistantRepository();
      assistant.requests[_request] = ConsentAlreadyGiven(
        Uri.parse('https://claude.ai/api/mcp/auth_callback?code=deja'),
      );
      await robot.pumpApp(
        auth: _signedIn(),
        assistant: assistant,
        pendingConsent: _request,
      );

      expect(robot.links.openedInPlace.single.queryParameters['code'], 'deja');
      expect(find.byKey(ConsentKeys.handedOver), findsOneWidget);
    });

    testWidgets('an expired request says so and leads home', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), pendingConsent: _request);

      robot.expectText(
        "Cette demande d'accès a expiré ou a déjà été traitée. "
        'Relance la connexion depuis ton assistant.',
      );
      await robot.tap(ConsentKeys.home);
      expect(find.byType(HomeScreen), findsOneWidget);

      // La demande est oubliée : naviguer (aller et retour) n'y ramène plus.
      await robot.openSocialTab();
      await robot.addFromSocial(GroupKeys.joinWithCode);
      await robot.goBack();
      expect(find.byKey(ConsentKeys.screen), findsNothing);
    });

    testWidgets('« not me » signs out, and the next sign-in comes back', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      final assistant = FakeAssistantRepository()..seedRequest(_request);
      await robot.pumpApp(
        auth: _signedIn(),
        assistant: assistant,
        pendingConsent: _request,
      );

      await robot.tap(ConsentKeys.notMe);
      robot.expectScreen(AuthKeys.signInScreen);
      await robot.signIn('zoe@test.local', 'motdepasse1');
      robot.expectScreen(ConsentKeys.screen);
    });
  });

  group('assistant screen', () {
    testWidgets('shows the address, the granted accesses, and revokes one', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      final assistant = FakeAssistantRepository()
        ..seedGrant('client-claude', 'Claude')
        ..seedGrant('client-cursor', '');
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await robot.pumpApp(
        auth: _signedIn(),
        assistant: assistant,
        mcpUrl: _mcp,
      );
      await robot.openProfile();
      await robot.tap(ProfileKeys.assistant);
      robot.expectScreen(AssistantKeys.screen);
      robot.expectText(_mcp.toString());

      await robot.tap(AssistantKeys.copyAddress);
      await robot.tap(AssistantKeys.copyCommand);
      expect(copied, [
        _mcp.toString(),
        'claude mcp add --transport http --scope user agora $_mcp',
      ]);

      expect(find.byKey(AssistantKeys.grant('client-claude')), findsOneWidget);
      robot.expectText('Assistant sans nom');
      await robot.tap(AssistantKeys.revoke('client-claude'));
      await robot.tap(AssistantKeys.confirmRevoke);
      expect(assistant.calls, contains('revoke client-claude'));
      expect(find.byKey(AssistantKeys.grant('client-claude')), findsNothing);
      expect(robot.logger.errorCount, 0);
    });

    testWidgets('with no access granted, says so', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), mcpUrl: _mcp);
      await robot.openProfile();
      await robot.tap(ProfileKeys.assistant);
      expect(find.byKey(AssistantKeys.noGrant), findsOneWidget);
    });

    testWidgets('while the server is not open, a calm notice, no error', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      final assistant = FakeAssistantRepository()
        ..grantsError = const AssistantsUnavailableException();
      await robot.pumpApp(
        auth: _signedIn(),
        assistant: assistant,
        mcpUrl: _mcp,
      );
      await robot.openProfile();
      await robot.tap(ProfileKeys.assistant);
      expect(find.byKey(AssistantKeys.unavailable), findsOneWidget);
    });
  });
}
