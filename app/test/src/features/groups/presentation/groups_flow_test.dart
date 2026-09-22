import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/agora_robot.dart';
import '../../../../helpers/fake_groups_repository.dart';
import '../../../../helpers/fakes.dart';

FakeAuthRepository _signedIn() => FakeAuthRepository(
  signedInAs: const AppUser(
    id: FakeAuthRepository.userId,
    email: 'zoe@test.local',
  ),
);

/// Mardi de la semaine affichée par défaut (elle commence le lundi), à
/// [hour] h locales. Passé ou à venir : la vue semaine montre les deux, et
/// un « prochain mardi » tomberait la semaine suivante un mardi après
/// [hour] h.
DateTime _tuesdayThisWeekAt(int hour) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day + 1, hour).toUtc();
}

FakeMember _lea() =>
    FakeMember('u-lea', 'Léa', GroupRole.member, ShareLevel.details);
FakeMember _max() =>
    FakeMember('u-max', 'Max', GroupRole.member, ShareLevel.busy);

/// Coloc, dont Léa est propriétaire, avec une invitation valable.
FakeGroupsRepository _colocToJoin() {
  final groups = FakeGroupsRepository();
  groups.groups['g-coloc'] = FakeGroup(
    'g-coloc',
    'Coloc',
    members: [FakeMember('u-lea', 'Léa', GroupRole.owner, ShareLevel.details)],
  );
  groups.seedInvite('ABCD2345', 'g-coloc');
  return groups;
}

void main() {
  testWidgets('creating a group opens it', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openGroupsTab();
    await robot.tap(GroupKeys.newGroup);
    await robot.enter(GroupKeys.name, 'Coloc');
    await robot.tap(GroupKeys.save);

    expect(robot.groups.calls, contains('createGroup'));
    robot.expectScreen(GroupKeys.groupScreen);
    expect(find.text('Coloc'), findsWidgets);
  });

  testWidgets('joining with a code asks what to share', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: _colocToJoin());

    await robot.openGroupsTab();
    await robot.tap(GroupKeys.joinWithCode);
    await robot.enter(GroupKeys.codeField, 'abcd2345');
    await robot.tap(GroupKeys.continueButton);
    robot.expectText('Rejoindre « Coloc » ?');
    robot.expectText('1 membre');
    await robot.tap(GroupKeys.shareOption(ShareLevel.invisible));
    await robot.tap(GroupKeys.joinButton);

    expect(robot.groups.joinedWith, ShareLevel.invisible);
    robot.expectScreen(GroupKeys.groupScreen);
  });

  testWidgets('sharing defaults to busy when joining', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: _colocToJoin());

    await robot.openLink('/join/ABCD2345');
    await robot.tap(GroupKeys.joinButton);

    expect(robot.groups.joinedWith, ShareLevel.busy);
  });

  testWidgets('an unknown code is refused without saying why', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: _colocToJoin());

    await robot.openLink('/join/ZZZZZZZZ');

    robot.expectText(
      'Ce code d\'invitation n\'est pas valable : inconnu, expiré ou déjà utilisé.',
    );
    expect(find.byKey(GroupKeys.joinButton), findsNothing);
  });

  testWidgets('an invitation opened signed out comes back after sign-in', (
    tester,
  ) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(groups: _colocToJoin());

    await robot.openLink('/join/ABCD2345');
    expect(find.text('Rejoindre « Coloc » ?'), findsNothing);
    await robot.signIn('zoe@test.local', 'motdepasse');

    robot.expectScreen(GroupKeys.joinScreen);
    robot.expectText('Rejoindre « Coloc » ?');
  });

  testWidgets('the group agenda shows details and busy slots, per member', (
    tester,
  ) async {
    final groups = FakeGroupsRepository();
    final coloc = groups.seedGroup(
      'g-coloc',
      'Coloc',
      others: [_lea(), _max()],
    );
    final yoga = _tuesdayThisWeekAt(18);
    final busy = _tuesdayThisWeekAt(10);
    coloc.agenda.addAll([
      GroupAgendaItem(
        eventId: 'e-yoga',
        userId: 'u-lea',
        level: ShareLevel.details,
        title: 'Yoga',
        start: yoga,
        end: yoga.add(const Duration(hours: 1)),
        isAllDay: false,
      ),
      GroupAgendaItem(
        userId: 'u-max',
        level: ShareLevel.busy,
        start: busy,
        end: busy.add(const Duration(hours: 1)),
        isAllDay: false,
      ),
    ]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    expect(find.text('Yoga'), findsWidgets);
    expect(find.text('Occupé'), findsWidgets);

    await robot.tap(GroupKeys.memberChip('u-lea'));
    expect(find.text('Yoga'), findsNothing);
    expect(find.text('Occupé'), findsWidgets);
  });

  testWidgets('the group toolbar works while the personal agenda stays below', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.toolbar.month);
    await robot.tap(GroupKeys.toolbar.today);

    robot.expectScreen(GroupKeys.groupScreen);
  });

  testWidgets('the owner makes a member admin, then hands the group over', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-coloc', 'Coloc', others: [_lea()]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.members);
    await robot.tap(GroupKeys.memberMenu('u-lea'));
    await robot.tap(GroupKeys.makeAdmin);
    robot.expectText('Rôle mis à jour.');

    await robot.tap(GroupKeys.memberMenu('u-lea'));
    await robot.tap(GroupKeys.transfer);
    robot.expectText('Transmettre le groupe à Léa ?');
    await robot.tap(GroupKeys.confirm);

    final members = groups.groups['g-coloc']!.members;
    expect(
      members.firstWhere((m) => m.userId == 'u-lea').role,
      GroupRole.owner,
    );
    expect(
      members.firstWhere((m) => m.userId == FakeGroupsRepository.me).role,
      GroupRole.admin,
    );
  });

  testWidgets('a member changes what they share with the group', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()
      ..seedGroup(
        'g-coloc',
        'Coloc',
        myRole: GroupRole.member,
        others: [_lea()],
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.members);
    expect(find.byKey(GroupKeys.memberMenu('u-lea')), findsNothing);
    await robot.tap(GroupKeys.myShare(ShareLevel.details));

    final me = groups.groups['g-coloc']!.members.firstWhere(
      (m) => m.userId == FakeGroupsRepository.me,
    );
    expect(me.share, ShareLevel.details);
    robot.expectText('Partage enregistré.');
  });

  testWidgets('a member leaves the group', (tester) async {
    final groups = FakeGroupsRepository()
      ..seedGroup(
        'g-coloc',
        'Coloc',
        myRole: GroupRole.member,
        others: [_lea()],
      );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.menu);
    await robot.tap(GroupKeys.leave);
    await robot.tap(GroupKeys.confirm);

    robot.expectScreen(GroupKeys.listScreen);
    expect(find.byKey(GroupKeys.groupTile('g-coloc')), findsNothing);
    robot.expectText('Vous avez quitté le groupe.');
  });

  testWidgets('the owner must hand the group over before leaving', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-coloc', 'Coloc', others: [_lea()]);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.menu);
    await robot.tap(GroupKeys.leave);

    robot.expectText(
      'Transmettez d\'abord le groupe à un autre membre pour pouvoir le quitter.',
    );
    expect(groups.calls, isNot(contains('leaveGroup')));
  });

  testWidgets('renaming a group keeps its description', (tester) async {
    final groups = FakeGroupsRepository();
    groups.seedGroup('g-coloc', 'Coloc').description = 'Appart de la rue X';
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.menu);
    await robot.tap(GroupKeys.rename);
    await robot.enter(GroupKeys.name, 'Coloc 2026');
    await robot.tap(GroupKeys.save);

    final group = groups.groups['g-coloc']!;
    expect(group.name, 'Coloc 2026');
    expect(group.description, 'Appart de la rue X');
    robot.expectText('Groupe enregistré.');
  });

  testWidgets('the owner deletes the group', (tester) async {
    final groups = FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.menu);
    await robot.tap(GroupKeys.delete);
    await robot.tap(GroupKeys.confirm);

    expect(groups.groups, isEmpty);
    robot.expectText('Groupe supprimé.');
  });

  testWidgets('the invite sheet reuses my code and offers the web link', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc');
    groups.seedInvite(
      'WXYZ2345',
      'g-coloc',
      createdBy: FakeGroupsRepository.me,
    );
    final robot = AgoraRobot(tester);
    await robot.pumpApp(
      auth: _signedIn(),
      groups: groups,
      webBaseUrl: Uri.parse('https://agora.example'),
    );

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
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

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.invite);

    expect(find.text('WXYZ2345'), findsOneWidget);
    expect(groups.calls, isNot(contains('createInvite')));
    await robot.tap(GroupKeys.copyLink);
    expect(copied, 'https://agora.example/#/join/WXYZ2345');
    robot.expectText('Lien copié.');
  });

  testWidgets('without a web address, only the code is offered', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()..seedGroup('g-coloc', 'Coloc');
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-coloc');
    await robot.tap(GroupKeys.invite);

    expect(find.byKey(GroupKeys.inviteCode), findsOneWidget);
    expect(groups.calls, contains('createInvite'));
    expect(find.byKey(GroupKeys.copyLink), findsNothing);
  });
}
