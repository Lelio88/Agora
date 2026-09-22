import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_groups_repository.dart';
import '../../../../helpers/fakes.dart';

void main() {
  late FakeGroupsRepository groups;
  late ProviderContainer container;

  setUp(() {
    groups = FakeGroupsRepository();
    // Mes groupes ne se lisent qu'avec un compte connecté.
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
    // Comme un écran : sans auditeur, Riverpod 3 met les providers en pause
    // et la session ne serait jamais connue.
    final sub = container.listen(myGroupsProvider, (_, _) {});
    addTearDown(sub.close);
  });

  GroupsService service() => container.read(groupsServiceProvider);

  test('the current invitation is reused rather than multiplied', () async {
    groups.seedGroup('g-1', 'Coloc');

    final first = await service().currentInvite('g-1');
    final second = await service().currentInvite('g-1');

    expect(second.code, first.code);
    expect(groups.calls.where((c) => c == 'createInvite'), hasLength(1));
  });

  test('joining refreshes the list of my groups', () async {
    groups.groups['g-1'] = FakeGroup('g-1', 'Coloc');
    groups.seedInvite('ABCD2345', 'g-1');
    expect(await container.read(myGroupsProvider.future), isEmpty);

    await service().join('ABCD2345', ShareLevel.details);

    final mine = await container.read(myGroupsProvider.future);
    expect(mine.single.name, 'Coloc');
    expect(mine.single.shareLevel, ShareLevel.details);
  });

  test('leaving refreshes the list of my groups', () async {
    groups.seedGroup('g-1', 'Coloc', myRole: GroupRole.member);
    expect(await container.read(myGroupsProvider.future), hasLength(1));

    await service().leave('g-1');

    expect(await container.read(myGroupsProvider.future), isEmpty);
  });

  test('only plausible codes reach the server', () {
    expect(looksLikeInviteCode('abcd2345'), isTrue);
    expect(looksLikeInviteCode(' ABCD2345 '), isTrue);
    expect(looksLikeInviteCode('ABCD234'), isFalse);
    // I, O, 0 et 1 n'existent pas dans l'alphabet des codes.
    expect(looksLikeInviteCode('ABCD0123'), isFalse);
    expect(looksLikeInviteCode("ABCD'; --"), isFalse);
  });
}
