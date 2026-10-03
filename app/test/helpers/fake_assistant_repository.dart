import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/assistant/domain/assistant.dart';

/// Faux [AssistantRepository] en mémoire : une demande d'accès par
/// identifiant, des accès accordés, et le journal des appels.
class FakeAssistantRepository implements AssistantRepository {
  final requests = <String, ConsentRequest>{};
  final grants = <AssistantGrant>[];
  final calls = <String>[];

  /// Erreur levée par le prochain appel, une seule fois.
  AppException? nextError;

  /// Erreur levée par chaque lecture des accès (serveur OAuth éteint…).
  AppException? grantsError;

  void _record(String call) {
    calls.add(call);
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  /// Une demande d'accès à trancher, venue de [redirectUri].
  void seedRequest(
    String id, {
    String redirectUri = 'https://claude.ai/api/mcp/auth_callback',
    String clientName = 'Claude',
    String email = 'zoe@test.local',
  }) => requests[id] = ConsentToDecide(
    clientName: clientName,
    redirectUri: redirectUri,
    email: email,
  );

  void seedGrant(String clientId, String name) => grants.add(
    AssistantGrant(
      clientId: clientId,
      name: name,
      grantedAt: DateTime.utc(2026, 10, 3),
    ),
  );

  static Uri _back(String redirectUri, Map<String, String> query) =>
      Uri.parse(redirectUri).replace(queryParameters: query);

  @override
  Future<ConsentRequest> fetchConsent(String authorizationId) async {
    _record('fetchConsent $authorizationId');
    final request = requests[authorizationId];
    if (request == null) throw const ConsentExpiredException();
    return request;
  }

  @override
  Future<Uri> approve(String authorizationId) async {
    _record('approve $authorizationId');
    final request = requests.remove(authorizationId);
    if (request is! ConsentToDecide) throw const ConsentExpiredException();
    return _back(request.redirectUri, {'code': 'code-$authorizationId'});
  }

  @override
  Future<Uri?> deny(String authorizationId) async {
    _record('deny $authorizationId');
    final request = requests.remove(authorizationId);
    if (request is! ConsentToDecide) throw const ConsentExpiredException();
    return _back(request.redirectUri, {'error': 'access_denied'});
  }

  @override
  Future<List<AssistantGrant>> listGrants() async {
    _record('listGrants');
    final error = grantsError;
    if (error != null) throw error;
    return List.of(grants);
  }

  @override
  Future<void> revoke(String clientId) async {
    _record('revoke $clientId');
    grants.removeWhere((grant) => grant.clientId == clientId);
  }
}
