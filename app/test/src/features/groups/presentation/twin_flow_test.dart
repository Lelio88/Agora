import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
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

const _state = 'etat-du-jumelage-0001';
const _request = '/twin?de=arpente&code=ABC234&nom=Sortie+Caen&etat=$_state';

Map<String, String> _fragment(Uri uri) => Uri.splitQueryString(uri.fragment);

void main() {
  group('a request from Arpente', () {
    testWidgets('twins a new group and answers Arpente', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn());

      await robot.openLink(_request);
      robot.expectText(
        'Le groupe Arpente « Sortie Caen » propose un jumelage.',
      );
      await robot.tap(GroupKeys.twinConfirm);

      final groupId = robot.groups.groups.keys.single;
      final twin = robot.groups.twins[groupId]!.single;
      expect(robot.groups.groups[groupId]!.name, 'Sortie Caen');
      expect(twin.remoteCode, 'ABC234');
      expect(robot.links.opened.single.path, '/jumeler.html');
      expect(_fragment(robot.links.opened.single), {
        'de': 'agora',
        'code': twin.inviteCode,
        'pour': 'ABC234',
        'etat': _state,
      });
      robot.expectScreen(GroupKeys.groupScreen);
      robot.expectText('Ce groupe existe aussi dans Arpente.');
    });

    testWidgets('can twin a group the user already manages', (tester) async {
      final groups = FakeGroupsRepository()
        ..seedGroup('g-1', 'Coloc', myRole: GroupRole.admin)
        ..seedGroup('g-2', 'Club', myRole: GroupRole.member);
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), groups: groups);

      await robot.openLink(_request);
      // Un groupe où l'on n'est que membre n'est pas proposé.
      expect(find.byKey(GroupKeys.twinGroupOption('g-2')), findsNothing);
      await robot.tap(GroupKeys.twinGroupOption('g-1'));
      await robot.tap(GroupKeys.twinConfirm);

      expect(groups.groups, hasLength(2));
      expect(groups.twins['g-1']!.single.remoteCode, 'ABC234');
    });

    testWidgets('opened signed out, comes back after sign-in', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp();

      // Tel qu'Android le transmet : la racine, et le fragment du web.
      await robot.openLink('/#$_request');
      await robot.signIn('zoe@test.local', 'motdepasse');

      robot.expectScreen(GroupKeys.twinScreen);
      robot.expectText(
        'Le groupe Arpente « Sortie Caen » propose un jumelage.',
      );
    });

    testWidgets('a malformed link is refused', (tester) async {
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn());

      await robot.openLink('/twin?de=arpente&code=ABC0EF&etat=$_state');

      robot.expectText("Ce lien de jumelage n'est pas valable.");
      expect(find.byKey(GroupKeys.twinConfirm), findsNothing);
    });
  });

  group('launched from Agora', () {
    testWidgets('an admin asks Arpente, then links its answer', (tester) async {
      final groups = FakeGroupsRepository()
        ..seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), groups: groups);

      await robot.openGroup('g-1');
      await robot.tap(GroupKeys.menu);
      await robot.tap(GroupKeys.twinMenu);
      await robot.tap(GroupKeys.twinStart(TwinApp.arpente));

      final request = _fragment(robot.links.opened.single);
      final invite = groups.twins['g-1']!.single.inviteCode;
      expect(request['code'], invite);
      expect(request['nom'], 'Coloc');

      await robot.openLink(
        '/twin?de=arpente&code=ABC234&pour=$invite&etat=${request['etat']}',
      );
      robot.expectText('Relier « Coloc » au groupe Arpente choisi ?');
      await robot.tap(GroupKeys.twinLink);

      expect(groups.twins['g-1']!.single.remoteCode, 'ABC234');
      robot.expectScreen(GroupKeys.groupScreen);
      await robot.tap(GroupKeys.twinJoin(TwinApp.arpente));
      expect(
        robot.links.opened.last.toString(),
        'https://arpente.heianenterprise.com/rejoindre.html#code=ABC234',
      );
    });

    testWidgets('an answer to a request not made here is refused', (
      tester,
    ) async {
      final groups = FakeGroupsRepository()
        ..seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), groups: groups);

      await robot.openLink(
        '/twin?de=arpente&code=ABC234&pour=WXYZ2345&etat=$_state',
      );

      robot.expectText(
        'Cette réponse ne correspond à aucun jumelage lancé depuis cet '
        'appareil. Relance le jumelage depuis le menu du groupe.',
      );
      expect(find.byKey(GroupKeys.twinLink), findsNothing);
    });

    testWidgets('an admin can unlink; the invitation stops working', (
      tester,
    ) async {
      final groups = FakeGroupsRepository()
        ..seedGroup('g-1', 'Coloc', myRole: GroupRole.owner);
      groups.invites['JUMXZ222'] = (groupId: 'g-1', createdBy: 'me');
      groups.twins['g-1'] = [
        const GroupTwin(
          app: TwinApp.arpente,
          inviteCode: 'JUMXZ222',
          remoteCode: 'ABC234',
        ),
      ];
      final robot = AgoraRobot(tester);
      await robot.pumpApp(auth: _signedIn(), groups: groups);

      await robot.openGroup('g-1');
      await robot.tap(GroupKeys.menu);
      await robot.tap(GroupKeys.twinMenu);
      await robot.tap(GroupKeys.twinUnlink(TwinApp.arpente));
      await robot.tap(GroupKeys.confirm);

      expect(groups.invites, isNot(contains('JUMXZ222')));
      expect(groups.twins['g-1'], isEmpty);
      expect(find.text('Ce groupe existe aussi dans Arpente.'), findsNothing);
    });
  });

  testWidgets('a member sees the twin but cannot manage it', (tester) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-1', 'Coloc', myRole: GroupRole.member);
    groups.twins['g-1'] = [
      const GroupTwin(
        app: TwinApp.arpente,
        inviteCode: 'JUMXZ222',
        remoteCode: 'ABC234',
      ),
    ];
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-1');
    robot.expectText('Ce groupe existe aussi dans Arpente.');
    await robot.tap(GroupKeys.menu);

    expect(find.byKey(GroupKeys.twinMenu), findsNothing);
  });

  testWidgets('joining a DewDrop circle is announced as a request', (
    tester,
  ) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-1', 'Coloc', myRole: GroupRole.member);
    groups.twins['g-1'] = [
      const GroupTwin(
        app: TwinApp.arpente,
        inviteCode: 'JUMXZ222',
        remoteCode: 'ABC234',
      ),
      const GroupTwin(
        app: TwinApp.dewdrop,
        inviteCode: 'JUMXZ333',
        remoteCode: 'WXYZ2345',
      ),
    ];
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-1');
    robot.expectText('Ce groupe existe aussi dans DewDrop.');
    robot.expectText('Demander à rejoindre');
    await robot.tap(GroupKeys.twinJoin(TwinApp.dewdrop));

    expect(
      robot.links.opened.last.toString(),
      'https://dewdrop.heianenterprise.com/rejoindre.html#code=WXYZ2345',
    );
  });

  testWidgets('an admin twins a group with DewDrop too', (tester) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openGroup('g-1');
    await robot.tap(GroupKeys.menu);
    await robot.tap(GroupKeys.twinMenu);
    await robot.tap(GroupKeys.twinStart(TwinApp.dewdrop));

    final request = robot.links.opened.single;
    expect(request.origin, 'https://dewdrop.heianenterprise.com');
    expect(_fragment(request)['nom'], 'Coloc');
    expect(groups.twins['g-1']!.single.app, TwinApp.dewdrop);
  });

  testWidgets('a second link replaces the first one on screen', (tester) async {
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn());

    await robot.openLink(_request);
    await robot.openLink(
      '/twin?de=arpente&code=DEF567&nom=Balade+Troyes&etat=$_state',
    );

    robot.expectText(
      'Le groupe Arpente « Balade Troyes » propose un jumelage.',
    );
    await robot.tap(GroupKeys.twinConfirm);
    expect(_fragment(robot.links.opened.single)['pour'], 'DEF567');
  });

  testWidgets('a group already twinned keeps its twin', (tester) async {
    final groups = FakeGroupsRepository()
      ..seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
    groups.invites['JUMXZ222'] = (groupId: 'g-1', createdBy: 'me');
    groups.twins['g-1'] = [
      const GroupTwin(
        app: TwinApp.arpente,
        inviteCode: 'JUMXZ222',
        remoteCode: 'XYZ789',
      ),
    ];
    final robot = AgoraRobot(tester);
    await robot.pumpApp(auth: _signedIn(), groups: groups);

    await robot.openLink(_request);
    await robot.tap(GroupKeys.twinGroupOption('g-1'));
    await robot.tap(GroupKeys.twinConfirm);

    robot.expectText(
      'Ce groupe est déjà jumelé avec un autre groupe de cette app. '
      "Défais d'abord ce jumelage depuis le menu du groupe.",
    );
    expect(groups.twins['g-1']!.single.remoteCode, 'XYZ789');
    expect(robot.links.opened, isEmpty);
  });
}
