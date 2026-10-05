/// Jumelage d'un groupe avec un groupe d'une autre app (Arpente) : lancer,
/// répondre, compléter, défaire. Le protocole et ses liens sont dans
/// `domain/twin.dart`.
///
/// Choix non évidents :
/// - les jumelages lancés depuis cet appareil ([TwinRequests]) vivent en
///   mémoire seulement. Une réponse n'est acceptée que si elle répond à une
///   demande partie d'ici : même jeton, même invitation. Sans cette règle, un
///   membre qui connaît une invitation du groupe pourrait forger une réponse
///   et faire rattacher un groupe Arpente à lui. Une app fermée entre-temps
///   fait relancer le jumelage, qui reprend la même invitation ;
/// - un lien de jumelage ouvert déconnecté est retenu ([PendingTwin]) le
///   temps de la connexion, comme une invitation ;
/// - les écritures passent par [GroupsService], qui invalide ce qu'elles
///   changent (liste des groupes, jumeaux).
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lien de jumelage ouvert alors que personne n'était connecté : le routeur
/// le retient le temps de la connexion, puis y ramène. L'écran de jumelage
/// le consomme.
final class PendingTwin {
  String? location;
}

final pendingTwinProvider = Provider<PendingTwin>((ref) => PendingTwin());

/// Une demande de jumelage partie de cet appareil.
typedef TwinRequestSent = ({TwinApp app, String groupId, String inviteCode});

/// Jumelages lancés depuis cet appareil, en attente de la réponse de l'autre
/// app, par jeton envoyé.
final class TwinRequests {
  final _byState = <String, TwinRequestSent>{};

  void remember(
    String state, {
    required TwinApp app,
    required String groupId,
    required String inviteCode,
  }) => _byState[state] = (app: app, groupId: groupId, inviteCode: inviteCode);

  /// La demande à laquelle répond [response] (même jeton, même app, même
  /// invitation), ou `null`.
  TwinRequestSent? match(TwinResponse response) {
    final request = _byState[response.state];
    if (request == null ||
        request.app != response.app ||
        request.inviteCode != response.forCode) {
      return null;
    }
    return request;
  }

  void forget(String state) => _byState.remove(state);
}

final twinRequestsProvider = Provider<TwinRequests>((ref) => TwinRequests());

/// Fabrique des jetons de jumelage ; remplacée dans les tests.
final twinStateGeneratorProvider = Provider<String Function()>(
  (ref) => newTwinState,
);

final class TwinService {
  const TwinService(this._groups, this._requests, this._newState);

  final GroupsService _groups;
  final TwinRequests _requests;
  final String Function() _newState;

  /// Lance le jumelage de [group] avec [app] : l'adresse de la demande à
  /// ouvrir. Relancer reprend la même invitation, avec un jeton neuf.
  Future<Uri> start(MyGroup group, TwinApp app) async {
    final inviteCode = await _groups.twin(group.id, app);
    final state = _newState();
    _requests.remember(
      state,
      app: app,
      groupId: group.id,
      inviteCode: inviteCode,
    );
    return twinRequestUri(
      app,
      inviteCode: inviteCode,
      name: group.name,
      state: state,
    );
  }

  /// Accepte une demande venue d'une autre app : jumelle le groupe [groupId],
  /// ou un nouveau groupe nommé [newGroupName] si [groupId] est nul. Rend le
  /// groupe et l'adresse de la réponse à ouvrir.
  Future<({String groupId, Uri response})> accept(
    TwinRequest request, {
    required String? groupId,
    required String newGroupName,
  }) async {
    final id = groupId ?? await _groups.create(name: newGroupName);
    final inviteCode = await _groups.twin(
      id,
      request.app,
      remoteCode: request.remoteCode,
    );
    return (
      groupId: id,
      response: twinResponseUri(
        request.app,
        inviteCode: inviteCode,
        forCode: request.remoteCode,
        state: request.state,
      ),
    );
  }

  /// Le groupe auquel répond [response], s'il a été lancé d'ici.
  String? groupFor(TwinResponse response) => _requests.match(response)?.groupId;

  /// Complète le jumelage que [response] achève ; l'id du groupe.
  Future<String> complete(TwinResponse response) async {
    final request = _requests.match(response);
    if (request == null) throw const InvalidTwinLinkException();
    await _groups.twin(
      request.groupId,
      response.app,
      remoteCode: response.remoteCode,
    );
    _requests.forget(response.state);
    return request.groupId;
  }

  Future<void> unlink(String groupId, GroupTwin twin) =>
      _groups.unlinkTwin(groupId, twin);
}

final twinServiceProvider = Provider<TwinService>(
  (ref) => TwinService(
    ref.watch(groupsServiceProvider),
    ref.watch(twinRequestsProvider),
    ref.watch(twinStateGeneratorProvider),
  ),
);
