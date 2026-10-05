import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/application/twin_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_groups_repository.dart';
import '../../../../helpers/fakes.dart';

const _state = 'etat-du-jumelage-0001';

void main() {
  late FakeGroupsRepository groups;
  late ProviderContainer container;

  setUp(() {
    groups = FakeGroupsRepository();
    final auth = FakeAuthRepository(
      signedInAs: const AppUser(
        id: FakeAuthRepository.userId,
        email: 'zoe@test.local',
      ),
    );
    container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        groupsRepositoryProvider.overrideWithValue(groups),
        twinStateGeneratorProvider.overrideWithValue(() => _state),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    final sub = container.listen(myGroupsProvider, (_, _) {});
    addTearDown(sub.close);
  });

  TwinService service() => container.read(twinServiceProvider);

  const coloc = MyGroup(
    id: 'g-1',
    name: 'Coloc',
    role: GroupRole.admin,
    shareLevel: ShareLevel.busy,
  );

  group('launched from Agora', () {
    test('asks Arpente with a pending twin and its invitation', () async {
      groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);

      final uri = await service().start(coloc, TwinApp.arpente);

      final twin = groups.twins['g-1']!.single;
      expect(twin.isPending, isTrue);
      expect(Uri.splitQueryString(uri.fragment), {
        'de': 'agora',
        'code': twin.inviteCode,
        'nom': 'Coloc',
        'etat': _state,
      });
    });

    test('completes the twin when Arpente answers this request', () async {
      groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
      await service().start(coloc, TwinApp.arpente);
      final invite = groups.twins['g-1']!.single.inviteCode;

      final groupId = await service().complete(
        TwinResponse(
          app: TwinApp.arpente,
          remoteCode: 'ABC234',
          state: _state,
          forCode: invite,
        ),
      );

      expect(groupId, 'g-1');
      expect(groups.twins['g-1']!.single.remoteCode, 'ABC234');
    });

    test('refuses an answer to a request not made here', () async {
      groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
      await service().start(coloc, TwinApp.arpente);
      final invite = groups.twins['g-1']!.single.inviteCode;

      for (final response in [
        TwinResponse(
          app: TwinApp.arpente,
          remoteCode: 'ABC234',
          state: 'un-autre-etat-0000000',
          forCode: invite,
        ),
        const TwinResponse(
          app: TwinApp.arpente,
          remoteCode: 'ABC234',
          state: _state,
          forCode: 'WXYZ2345',
        ),
      ]) {
        expect(service().groupFor(response), isNull);
        await expectLater(
          service().complete(response),
          throwsA(isA<InvalidTwinLinkException>()),
        );
      }
      expect(groups.twins['g-1']!.single.isPending, isTrue);
    });

    test('a simple member cannot launch a twin', () async {
      groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.member);

      await expectLater(
        service().start(coloc, TwinApp.arpente),
        throwsA(isA<NotGroupAdminException>()),
      );
    });
  });

  group('answering a request from Arpente', () {
    const request = TwinRequest(
      app: TwinApp.arpente,
      remoteCode: 'ABC234',
      state: _state,
      name: 'Sortie Caen',
    );

    test('a new group is created, twinned, and the answer built', () async {
      final answer = await service().accept(
        request,
        groupId: null,
        newGroupName: 'Sortie Caen',
      );

      expect(groups.groups[answer.groupId]!.name, 'Sortie Caen');
      final twin = groups.twins[answer.groupId]!.single;
      expect(twin.remoteCode, 'ABC234');
      expect(Uri.splitQueryString(answer.response.fragment), {
        'de': 'agora',
        'code': twin.inviteCode,
        'pour': 'ABC234',
        'etat': _state,
      });
    });

    test('an existing group the user manages can be twinned', () async {
      groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.owner);

      final answer = await service().accept(
        request,
        groupId: 'g-1',
        newGroupName: 'ignoré',
      );

      expect(answer.groupId, 'g-1');
      expect(groups.groups, hasLength(1));
      expect(groups.twins['g-1']!.single.remoteCode, 'ABC234');
    });
  });

  test('unlinking revokes the invitation given to the other app', () async {
    groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.admin);
    await service().start(coloc, TwinApp.arpente);
    final twin = groups.twins['g-1']!.single;

    await service().unlink('g-1', twin);

    expect(groups.invites, isNot(contains(twin.inviteCode)));
    expect(groups.twins['g-1'], isEmpty);
  });
}
