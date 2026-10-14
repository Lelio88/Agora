import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/profile/presentation/profile_keys.dart';
import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_profile_link_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

final _web = Uri.parse('https://agora.example');

/// Ouvre « Partager mon profil » depuis l'onglet Moi.
Future<void> _openLinks(AgoraRobot robot) async {
  await robot.openProfile();
  await robot.tap(ProfileKeys.profileLinks);
}

Future<void> _createLink(
  AgoraRobot robot,
  String label, {
  ProfileLinkLevel? level,
}) async {
  await robot.tap(ProfileLinkKeys.newLink);
  await robot.enter(ProfileLinkKeys.labelField, label);
  if (level != null) await robot.tap(ProfileLinkKeys.levelOption(level));
  await robot.tap(ProfileLinkKeys.create);
}

void main() {
  group('my links', () {
    testWidgets('start empty and explain what a link does', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), webBaseUrl: _web);

      await _openLinks(robot);

      robot.expectScreen(ProfileLinkKeys.screen);
      robot.expectText("Aucun lien pour l'instant.");
      expect(find.textContaining('ne se met pas à jour'), findsOneWidget);
    });

    testWidgets('a new link is named, quiet by default, and shows its QR', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), webBaseUrl: _web);
      await _openLinks(robot);

      await _createLink(robot, 'Marie');

      final link = robot.profileLinks.links.single;
      expect(link.label, 'Marie');
      expect(link.level, ProfileLinkLevel.busy);
      // La fenêtre du lien s'ouvre aussitôt, avec le QR code de l'adresse web.
      final qr = tester.widget<QrImageView>(find.byKey(ProfileLinkKeys.qr));
      expect(qr.backgroundColor, Colors.white);
      expect(
        tester.widget<SelectableText>(find.byKey(ProfileLinkKeys.url)).data,
        'https://agora.example/#/profile/${link.code}',
      );
    });

    testWidgets('the level is chosen when the link is created', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), webBaseUrl: _web);
      await _openLinks(robot);

      await _createLink(robot, 'Papa', level: ProfileLinkLevel.details);
      await robot.dismissSheet();

      expect(robot.profileLinks.links.single.level, ProfileLinkLevel.details);
      final code = robot.profileLinks.links.single.code;
      expect(find.byKey(ProfileLinkKeys.tile(code)), findsOneWidget);
      robot.expectText('Voit les titres et les lieux');
    });

    testWidgets('a link needs a name', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), webBaseUrl: _web);
      await _openLinks(robot);

      await _createLink(robot, '   ');

      expect(robot.profileLinks.links, isEmpty);
      robot.expectText('Donne un nom à ce lien.');
    });

    testWidgets('can be shared and copied from its window', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), webBaseUrl: _web);
      await _openLinks(robot);
      await _createLink(robot, 'Marie');

      await robot.tap(ProfileLinkKeys.share);

      final code = robot.profileLinks.links.single.code;
      expect(
        robot.sharer.shared.single,
        'Retrouve mon agenda sur Agora : https://agora.example/#/profile/$code',
      );
    });

    testWidgets('without a web address there is no link to show', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn());
      await _openLinks(robot);

      await _createLink(robot, 'Marie');

      expect(find.byKey(ProfileLinkKeys.qr), findsNothing);
      robot.expectText(
        "Cette version n'a pas d'adresse web : le lien n'est pas disponible.",
      );
    });

    testWidgets('deleting a link closes its window and clears the list', (
      tester,
    ) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), webBaseUrl: _web);
      await _openLinks(robot);
      await _createLink(robot, 'Marie');
      final code = robot.profileLinks.links.single.code;

      await robot.tap(ProfileLinkKeys.revoke);

      expect(robot.profileLinks.links, isEmpty);
      expect(find.byKey(ProfileLinkKeys.qr), findsNothing);
      expect(find.byKey(ProfileLinkKeys.tile(code)), findsNothing);
      robot.expectText('Lien supprimé.');
    });

    testWidgets('the twenty-link limit is explained', (tester) async {
      final repository = FakeProfileLinkRepository();
      for (var i = 0; i < 20; i++) {
        await repository.create(label: 'Lien $i', level: ProfileLinkLevel.busy);
      }
      final robot = AgoraRobot(tester);
      await robot.pumpApp(
        auth: _signedIn(),
        webBaseUrl: _web,
        profileLinks: repository,
      );
      await _openLinks(robot);

      await _createLink(robot, 'Un de trop');

      robot.expectText(
        "Tu as déjà 20 liens de profil : supprime-en un avant d'en créer un autre.",
      );
    });
  });

  group('a link received', () {
    FakeProfileLinkRepository withLea() =>
        FakeProfileLinkRepository()..others['LEA23456'] = 'Léa';

    testWidgets('shows who it is, copies nothing until confirmed', (
      tester,
    ) async {
      final profileLinks = withLea();
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), profileLinks: profileLinks);

      await robot.openLink('/profile/LEA23456');

      robot.expectScreen(ProfileLinkKeys.openScreen);
      robot.expectText('Créer un proche pour Léa ?');
      expect(profileLinks.imported, isEmpty);
    });

    testWidgets('creates the close one and opens its page', (tester) async {
      final profileLinks = withLea();
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), profileLinks: profileLinks);
      await robot.openLink('/profile/LEA23456');

      await robot.tap(ProfileLinkKeys.openConfirm);

      expect(profileLinks.imported, ['LEA23456']);
      final created = robot.calendars.calendars.last;
      expect((created.name, created.isContact), ('Léa', true));
      robot.expectScreen(CalendarKeys.contactScreen);
      robot.expectText('Léa est dans tes proches.');
    });

    testWidgets('opened a second time, it refreshes the same close one', (
      tester,
    ) async {
      final profileLinks = withLea();
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), profileLinks: profileLinks);
      await robot.openLink('/profile/LEA23456');
      await robot.tap(ProfileLinkKeys.openConfirm);
      final before = robot.calendars.calendars.length;

      await robot.openLink('/profile/LEA23456');
      await robot.tap(ProfileLinkKeys.openConfirm);

      expect(profileLinks.imported, hasLength(2));
      expect(robot.calendars.calendars, hasLength(before));
    });

    testWidgets('accepts the web fragment form and lower case', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), profileLinks: withLea());

      // Tel qu'Android le transmet : la racine, et le fragment du web.
      await robot.openLink('/#/profile/lea23456');

      robot.expectText('Créer un proche pour Léa ?');
    });

    testWidgets('an unknown or deleted link is refused', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), profileLinks: withLea());

      await robot.openLink('/profile/ZZZZZ234');

      robot.expectText("Ce lien de profil n'est plus valable.");
      expect(find.byKey(ProfileLinkKeys.openConfirm), findsNothing);
    });

    testWidgets('one\'s own link is refused when confirmed', (tester) async {
      final profileLinks = withLea();
      final own = await profileLinks.create(
        label: 'Moi',
        level: ProfileLinkLevel.busy,
      );
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), profileLinks: profileLinks);
      await robot.openLink('/profile/${own.code}');

      await robot.tap(ProfileLinkKeys.openConfirm);

      robot.expectText(
        "C'est ton propre profil : partage ce lien à quelqu'un d'autre.",
      );
      expect(profileLinks.imported, isEmpty);
    });

    testWidgets('opened signed out, comes back after sign-in', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(profileLinks: withLea());

      await robot.openLink('/#/profile/LEA23456');
      await robot.signIn('zoe@test.local', 'motdepasse');

      robot.expectScreen(ProfileLinkKeys.openScreen);
      robot.expectText('Créer un proche pour Léa ?');
    });
  });
}
