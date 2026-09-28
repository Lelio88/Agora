import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/discord/domain/discord.dart';
import 'package:agora/src/features/discord/presentation/discord_keys.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_discord_repository.dart';
import '../../../../helpers/fake_groups_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

FakeGroupsRepository _coloc({GroupRole role = GroupRole.owner}) =>
    FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc', myRole: role);

Future<void> _openDiscordChannel(AgoraRobot robot) async {
  await robot.openGroup('g-coloc');
  await robot.tap(GroupKeys.menu);
  await robot.tap(GroupKeys.discord);
  robot.expectScreen(DiscordKeys.channelScreen);
}

void main() {
  testWidgets('linking Discord from the profile shows the linked account', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());
    await robot.openProfile();

    await robot.scrollTo(DiscordKeys.linkAccount);
    await robot.tap(DiscordKeys.linkAccount);
    expect(robot.discord.calls, contains('linkAccount'));

    // Retour de Discord : la session change, le profil le montre.
    robot.discord.completeLink('Zoé#Discord');
    await robot.settle();
    robot.expectText('Relié à Zoé#Discord');

    await robot.tap(DiscordKeys.unlinkAccount);
    expect(robot.discord.calls, contains('unlinkAccount'));
    expect(find.byKey(DiscordKeys.linkAccount), findsOneWidget);
    expect(robot.logger.errorCount, 0);
  });

  testWidgets('a Discord account used elsewhere is refused with a reason', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    final discord = FakeDiscordRepository();
    await robot.pumpApp(auth: _signedIn(), discord: discord);
    await robot.openProfile();
    await robot.scrollTo(DiscordKeys.linkAccount);

    discord.nextError = const DiscordAlreadyLinkedException();
    await robot.tap(DiscordKeys.linkAccount);

    robot.expectText(
      'Ce compte Discord est déjà relié à un autre compte Agora.',
    );
  });

  testWidgets('an admin creates a code, then sees the linked channel', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: _coloc());
    await _openDiscordChannel(robot);

    robot.expectText("Aucun salon Discord n'est relié à ce groupe.");
    await robot.tap(DiscordKeys.createCode);
    robot.expectText('/relier K7PQ2MXA');

    // La commande est tapée dans Discord, puis l'admin revient.
    robot.discord.linkChannelFromDiscord('g-coloc', 'général');
    await robot.tap(DiscordKeys.checkLink);
    robot.expectText('Relié à #général');
    expect(find.byKey(DiscordKeys.recap), findsOneWidget);
  });

  testWidgets('an admin sets a daily recap, saved at once', (tester) async {
    final robot = AgoraRobot(tester);
    final discord = FakeDiscordRepository()
      ..linkChannelFromDiscord('g-coloc', 'général');
    await robot.pumpApp(auth: _signedIn(), groups: _coloc(), discord: discord);
    await _openDiscordChannel(robot);

    await tester.tap(find.text('Chaque jour'));
    await robot.settle();

    expect(discord.calls, contains('saveChannel'));
    expect(discord.channels['g-coloc']?.recap, DiscordRecap.daily);
    robot.expectText('Réglages enregistrés.');
    // Quotidien : plus de jour de la semaine à choisir.
    expect(find.byKey(DiscordKeys.recapWeekday), findsNothing);
  });

  testWidgets('an admin unlinks the channel', (tester) async {
    final robot = AgoraRobot(tester);
    final discord = FakeDiscordRepository()
      ..linkChannelFromDiscord('g-coloc', 'général');
    await robot.pumpApp(auth: _signedIn(), groups: _coloc(), discord: discord);
    await _openDiscordChannel(robot);

    await robot.scrollTo(DiscordKeys.unlinkChannel);
    await robot.tap(DiscordKeys.unlinkChannel);

    expect(discord.channels, isEmpty);
    robot.expectText("Aucun salon Discord n'est relié à ce groupe.");
  });

  testWidgets('a simple member only sees whether a channel is linked', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _coloc(role: GroupRole.member),
    );
    await _openDiscordChannel(robot);

    robot.expectText('Un admin du groupe peut en relier un.');
    expect(find.byKey(DiscordKeys.createCode), findsNothing);
  });

  testWidgets('the bot invite opens Discord when the build knows the bot', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: _coloc(),
      discordBotInvite: Uri.parse('https://discord.com/oauth2/authorize?x=1'),
    );
    await _openDiscordChannel(robot);

    await robot.tap(DiscordKeys.inviteBot);
    expect(robot.links.opened.single.host, 'discord.com');
    expect(find.byType(SnackBar), findsNothing);
  });
}
