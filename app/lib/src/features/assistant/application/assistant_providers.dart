/// Providers des assistants IA : l'adresse du serveur MCP, la demande d'accès
/// en attente, les accès accordés, et le service qui les tranche ou les
/// retire.
///
/// Choix non évidents :
/// - **la demande en attente vient de l'adresse de la page** (web) : GoTrue
///   renvoie le navigateur sur `/oauth/consent?authorization_id=…`, un vrai
///   chemin (le routage de l'app passe par le fragment, et l'App Link
///   Android ne vise que `/`). `main.dart` la lit dans l'adresse réelle de la page (`pageLocation`) au
///   démarrage ([consentRequestIn]) ; elle survit ainsi à un rechargement,
///   y compris au retour d'une connexion Google ou Discord, qui revient sur
///   la même adresse. Le routeur la retient aussi le temps d'une connexion
///   par mot de passe ;
/// - l'adresse du serveur MCP (`<API>/mcp`) est surchargée par `main.dart`
///   depuis la configuration du build : sans elle, l'écran ne propose rien.
library;

import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => throw UnimplementedError(
    'assistantRepositoryProvider must be overridden at the composition root.',
  ),
);

/// Chemin de l'écran de consentement : celui que GoTrue reçoit
/// (`GOTRUE_OAUTH_SERVER_AUTHORIZATION_PATH`).
const consentPath = '/oauth/consent';

/// Adresse du serveur MCP, ou `null` si le build ne connaît pas l'API.
final mcpUrlProvider = Provider<Uri?>((ref) => null);

/// L'adresse du serveur MCP pour une API Supabase.
Uri mcpUrlFor(Uri api) =>
    api.replace(path: '${api.path.replaceAll(RegExp(r'/+$'), '')}/mcp');

/// La commande qui branche Agora dans Claude Code, pour tous les dossiers.
String claudeCodeCommand(Uri mcpUrl) =>
    'claude mcp add --transport http --scope user agora $mcpUrl';

/// Une demande d'accès en attente de décision, retenue à travers la
/// connexion ; l'écran de consentement l'efface une fois traitée.
final class PendingConsent {
  PendingConsent([this.authorizationId]);

  String? authorizationId;
}

final pendingConsentProvider = Provider<PendingConsent>(
  (ref) => PendingConsent(),
);

final _authorizationId = RegExp(r'^[A-Za-z0-9_-]{8,128}$');

/// L'identifiant de demande d'accès porté par [uri] (adresse de la page),
/// ou `null` si ce n'est pas celle de l'écran de consentement.
String? consentRequestIn(Uri uri) {
  if (uri.path != consentPath) return null;
  final id = uri.queryParameters['authorization_id'];
  return id != null && _authorizationId.hasMatch(id) ? id : null;
}

/// La demande d'accès [authorizationId], lue sur le serveur d'autorisation.
final consentRequestProvider = FutureProvider.autoDispose
    .family<ConsentRequest, String>(
      (ref, authorizationId) =>
          ref.watch(assistantRepositoryProvider).fetchConsent(authorizationId),
    );

/// Les accès accordés, du plus récent au plus ancien.
final assistantGrantsProvider =
    FutureProvider.autoDispose<List<AssistantGrant>>(
      (ref) => ref.watch(assistantRepositoryProvider).listGrants(),
    );

final class AssistantService {
  const AssistantService(this._repository, this._pending, this._invalidate);

  final AssistantRepository _repository;
  final PendingConsent _pending;
  final void Function() _invalidate;

  /// Accorde l'accès et rend l'adresse de retour de l'assistant.
  Future<Uri> approve(String authorizationId) async {
    final back = await _repository.approve(authorizationId);
    _pending.authorizationId = null;
    _invalidate();
    return back;
  }

  /// Refuse l'accès ; rend l'adresse de retour s'il y en a une.
  Future<Uri?> deny(String authorizationId) async {
    final back = await _repository.deny(authorizationId);
    _pending.authorizationId = null;
    return back;
  }

  /// La demande est réglée sans décision (expirée, déjà accordée) : ne plus y
  /// ramener.
  void forget() => _pending.authorizationId = null;

  Future<void> revoke(String clientId) async {
    await _repository.revoke(clientId);
    _invalidate();
  }
}

final assistantServiceProvider = Provider<AssistantService>(
  (ref) => AssistantService(
    ref.watch(assistantRepositoryProvider),
    ref.watch(pendingConsentProvider),
    () => ref.invalidate(assistantGrantsProvider),
  ),
);
