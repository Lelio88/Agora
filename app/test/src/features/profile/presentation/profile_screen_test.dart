import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/presentation/auth_keys.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

Profile? _stored(AgoraRobot robot) =>
    robot.profiles.profiles[FakeAuthRepository.userId];

void main() {
  testWidgets('shows the email, name and time zone', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openProfile();

    robot.expectScreen(ProfileKeys.screen);
    robot.expectText('zoe@test.local');
    robot.expectText('Europe/Paris');
    expect(find.widgetWithText(TextFormField, 'Zoé'), findsOneWidget);
  });

  testWidgets('saves the device time zone and a new name', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), deviceTimezone: 'America/Montreal');
    await robot.openProfile();

    await robot.tap(ProfileKeys.useDeviceTimezone);
    await robot.enter(ProfileKeys.displayName, 'Zoé M.');
    await robot.tap(ProfileKeys.save);

    expect(_stored(robot)?.timezone, 'America/Montreal');
    expect(_stored(robot)?.displayName, 'Zoé M.');
    robot.expectText('Profil enregistré.');
  });

  testWidgets('switching to English translates the app', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), locale: null);
    await robot.openProfile();
    robot.expectText('Profil');

    await robot.selectLanguage('English');
    await robot.tap(ProfileKeys.save);

    expect(_stored(robot)?.language, AppLanguage.en);
    robot.expectText('Profile');
  });

  testWidgets('refuses an empty name without calling the server', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());
    await robot.openProfile();

    await robot.enter(ProfileKeys.displayName, '   ');
    await robot.tap(ProfileKeys.save);

    robot.expectText('Entre 1 et 60 caractères.');
    expect(_stored(robot)?.displayName, 'Zoé');
  });

  testWidgets('shows the server refusal of a time zone', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());
    await robot.openProfile();
    robot.profiles.nextError = const InvalidTimezoneException();

    await robot.tap(ProfileKeys.save);

    robot.expectText('Fuseau horaire inconnu.');
  });

  testWidgets('signing out returns to the sign-in screen', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());
    await robot.openProfile();

    await robot.tap(ProfileKeys.signOut);

    robot.expectScreen(AuthKeys.signInScreen);
  });
}
