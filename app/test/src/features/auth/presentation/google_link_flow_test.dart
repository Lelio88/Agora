import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/linked_account.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

void main() {
  testWidgets('linking Google from the profile shows the linked address', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      signInProviders: const [SocialProvider.google, SocialProvider.discord],
    );
    await robot.openProfile();

    await robot.scrollTo(AuthKeys.linkAccount(SocialProvider.google));
    await robot.tap(AuthKeys.linkAccount(SocialProvider.google));
    expect(robot.auth.calls, contains('linkAccount:google'));

    // Retour de Google : la session change, le profil le montre.
    robot.auth.completeLink(SocialProvider.google, 'zoe@gmail.com');
    await robot.settle();
    robot.expectText('Relié à zoe@gmail.com');

    await robot.tap(AuthKeys.unlinkAccount(SocialProvider.google));
    expect(robot.auth.calls, contains('unlinkAccount:google'));
    expect(
      find.byKey(AuthKeys.linkAccount(SocialProvider.google)),
      findsOneWidget,
    );
    expect(robot.logger.errorCount, 0);
  });

  testWidgets('an account opened with Google alone cannot unlink it', (
    tester,
  ) async {
    final auth = _signedIn()
      ..linked[SocialProvider.google] = const LinkedAccount(
        label: 'zoe@gmail.com',
        isOnlyWayIn: true,
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: auth,
      signInProviders: const [SocialProvider.google],
    );
    await robot.openProfile();
    await robot.scrollTo(AuthKeys.account(SocialProvider.google));

    robot.expectText('Tu te connectes avec zoe@gmail.com.');
    expect(
      find.byKey(AuthKeys.unlinkAccount(SocialProvider.google)),
      findsNothing,
    );
  });

  testWidgets('a Google account used elsewhere is refused with a reason', (
    tester,
  ) async {
    final auth = _signedIn();
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: auth,
      signInProviders: const [SocialProvider.google],
    );
    await robot.openProfile();
    await robot.scrollTo(AuthKeys.linkAccount(SocialProvider.google));

    auth.nextError = const GoogleAlreadyLinkedException();
    await robot.tap(AuthKeys.linkAccount(SocialProvider.google));

    robot.expectText(
      'Ce compte Google est déjà relié à un autre compte Agora.',
    );
  });

  testWidgets('no Google line when the build does not offer Google', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      signInProviders: const [SocialProvider.discord],
    );
    await robot.openProfile();

    expect(find.byKey(AuthKeys.account(SocialProvider.google)), findsNothing);
  });
}
