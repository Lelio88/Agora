import 'package:agora/src/config/sign_in_providers.dart';
import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/social_provider.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';

const _both = [SocialProvider.google, SocialProvider.discord];

void main() {
  group('parseSignInProviders', () {
    test('keeps the known providers, in order, once each', () {
      expect(parseSignInProviders(' discord, google ,discord'), [
        SocialProvider.discord,
        SocialProvider.google,
      ]);
    });

    test('offers nothing without configuration or with unknown names', () {
      expect(parseSignInProviders(''), isEmpty);
      expect(parseSignInProviders('apple,github'), isEmpty);
    });
  });

  testWidgets('continuing with Google opens its page, then the app', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(signInProviders: _both);
    robot.expectScreen(AuthKeys.signInScreen);

    await robot.tap(AuthKeys.socialSignIn('google'));
    expect(robot.auth.socialSignIns, [SocialProvider.google]);

    // Retour de Google : la session s'ouvre, le routeur quitte l'écran.
    robot.auth.completeSocialSignIn('zoe@gmail.com');
    await robot.settle();
    robot.expectScreen(HomeKeys.screen);
    expect(robot.logger.errorCount, 0);
  });

  testWidgets('creating an account offers the same shortcuts', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(signInProviders: _both);
    await robot.tap(AuthKeys.signUpLink);

    await robot.scrollTo(AuthKeys.socialSignIn('discord'));
    await robot.tap(AuthKeys.socialSignIn('discord'));

    expect(robot.auth.socialSignIns, [SocialProvider.discord]);
  });

  testWidgets('without configured providers, only the e-mail form shows', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();

    expect(find.byKey(AuthKeys.socialSignIn('google')), findsNothing);
    expect(find.text('ou'), findsNothing);
  });

  testWidgets('says so when the page cannot open', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(signInProviders: _both);
    robot.auth.socialOpens = false;

    await robot.tap(AuthKeys.socialSignIn('google'));

    robot.expectText("Impossible d'ouvrir la page de connexion.");
    robot.expectScreen(AuthKeys.signInScreen);
  });

  testWidgets('a network failure is explained', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(signInProviders: _both);
    robot.auth.nextError = const NetworkException();

    await robot.tap(AuthKeys.socialSignIn('discord'));

    expect(find.textContaining('serveur'), findsWidgets);
    robot.expectScreen(AuthKeys.signInScreen);
  });
}
