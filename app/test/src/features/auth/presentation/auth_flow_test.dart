import 'dart:async';

import 'package:agora/src/app.dart';
import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/home/presentation/home_screen.dart';
import 'package:agora/src/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fakes.dart';

void main() {
  testWidgets('a signed-out visitor lands on the sign-in screen', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();

    robot.expectScreen(AuthKeys.signInScreen);
  });

  testWidgets('signing in opens the home screen with the profile name', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();

    await robot.signIn('zoe@test.local', 'motdepasse1');

    robot.expectScreen(HomeKeys.screen);
  });

  testWidgets('wrong credentials show a message that reveals nothing', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    robot.auth.nextError = const InvalidCredentialsException();

    await robot.signIn('zoe@test.local', 'mauvais123');

    robot.expectScreen(AuthKeys.signInScreen);
    robot.expectText('Adresse ou mot de passe incorrect.');
  });

  testWidgets('an unconfirmed email gets a new code and the code screen', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    robot.auth.nextError = const EmailNotConfirmedException();
    await robot.signIn('zoe@test.local', 'motdepasse1');

    await robot.tap(AuthKeys.confirmEmailAction);

    expect(robot.auth.calls, contains('resendSignUpCode'));
    robot.expectScreen(AuthKeys.verifyEmailScreen);
    robot.expectText(
      'Nous avons envoyé un code à 6 chiffres à zoe@test.local.',
    );
  });

  testWidgets('sign-up sends name, language and device time zone', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(deviceTimezone: 'America/Montreal');
    await robot.tap(AuthKeys.signUpLink);

    await robot.enter(AuthKeys.displayName, 'Zoé');
    await robot.enter(AuthKeys.email, 'zoe@test.local');
    await robot.enter(AuthKeys.password, 'motdepasse1');
    await robot.tap(AuthKeys.submit);

    expect(robot.auth.lastSignUp, {
      'email': 'zoe@test.local',
      'displayName': 'Zoé',
      'locale': 'fr',
      'timezone': 'America/Montreal',
    });
    robot.expectScreen(AuthKeys.verifyEmailScreen);
  });

  testWidgets('sign-up refuses a password without digits, offline', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    await robot.tap(AuthKeys.signUpLink);

    await robot.enter(AuthKeys.displayName, 'Zoé');
    await robot.enter(AuthKeys.email, 'zoe@test.local');
    await robot.enter(AuthKeys.password, 'abcdefgh');
    await robot.tap(AuthKeys.submit);

    expect(robot.auth.calls, isEmpty);
    robot.expectText('Il faut des lettres et des chiffres.');
  });

  testWidgets('the right code confirms the account and opens home', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    robot.auth.nextError = const EmailNotConfirmedException();
    await robot.signIn('zoe@test.local', 'motdepasse1');
    await robot.tap(AuthKeys.confirmEmailAction);

    await robot.enter(AuthKeys.code, FakeAuthRepository.validCode);
    await robot.tap(AuthKeys.submit);

    robot.expectScreen(HomeKeys.screen);
  });

  testWidgets('a wrong code keeps the code screen with a message', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    robot.auth.nextError = const EmailNotConfirmedException();
    await robot.signIn('zoe@test.local', 'motdepasse1');
    await robot.tap(AuthKeys.confirmEmailAction);

    await robot.enter(AuthKeys.code, '000000');
    await robot.tap(AuthKeys.submit);

    robot.expectScreen(AuthKeys.verifyEmailScreen);
    robot.expectText('Code incorrect ou expiré.');
  });

  testWidgets('a forgotten password is replaced with a code', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    await robot.tap(AuthKeys.forgotPasswordLink);
    await robot.enter(AuthKeys.email, 'zoe@test.local');
    await robot.tap(AuthKeys.submit);
    robot.expectScreen(AuthKeys.resetPasswordScreen);

    await robot.enter(AuthKeys.code, FakeAuthRepository.validCode);
    await robot.enter(AuthKeys.newPassword, 'nouveau123');
    await robot.tap(AuthKeys.submit);

    expect(robot.auth.lastNewPassword, 'nouveau123');
    robot.expectScreen(HomeKeys.screen);
  });

  testWidgets('the sign-in screen speaks English on an English device', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(locale: const Locale('en'));

    expect(find.text('Sign in'), findsWidgets);
    robot.expectText('Forgot your password?');
  });

  testWidgets('links stay inert while a sign-in is in flight', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp();
    robot.auth.gate = Completer<void>();
    await robot.enter(AuthKeys.email, 'zoe@test.local');
    await robot.enter(AuthKeys.password, 'motdepasse1');
    await tester.tap(find.byKey(AuthKeys.submit));
    await tester.pump();

    await tester.tap(find.byKey(AuthKeys.signUpLink), warnIfMissed: false);
    await tester.pump();
    robot.expectScreen(AuthKeys.signInScreen);

    robot.auth.gate!.complete();
    await tester.pumpAndSettle();
    robot.expectScreen(HomeKeys.screen);
  });

  for (final location in ['/verify-email', '/reset-password']) {
    testWidgets('$location without an email falls back to sign-in', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AgoraApp)),
      );

      container.read(goRouterProvider).go(location);
      await tester.pumpAndSettle();

      robot.expectScreen(AuthKeys.signInScreen);
    });
  }
}
