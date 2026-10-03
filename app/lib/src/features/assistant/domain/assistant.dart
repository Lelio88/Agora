/// Les assistants IA branchés sur Agora (serveur MCP du worker) : qui les
/// reconnaît, ce que l'utilisateur leur a accordé, et la demande d'accès qu'il
/// doit trancher.
///
/// Choix non évidents :
/// - **seuls les assistants reconnus peuvent être autorisés**, à leur adresse
///   de retour exacte, chemin compris ([recognizeAssistant]). L'inscription
///   des clients OAuth est ouverte : une application malveillante peut
///   s'appeler « Claude », elle ne peut pas faire remettre le code ailleurs
///   qu'à l'adresse qu'elle a déclarée. Le nom que le client se donne n'est
///   montré que comme « se présente comme » ;
/// - une adresse de la machine (`localhost`, `127.0.0.1`, `[::1]`) est sûre
///   quel que soit son port ou son chemin : le code ne quitte pas l'ordinateur
///   (Claude Code, Cursor, VS Code y écoutent) ;
/// - ailleurs, le chemin compte : un domaine seul laisserait passer une
///   redirection ouverte de ce domaine.
///
/// Invariant : seules des `AppException` sortent du dépôt. Ajouter un
/// assistant, c'est une ligne de plus dans [recognizeAssistant], adresse
/// relevée dans sa documentation.
library;

/// Un assistant reconnu par son adresse de retour.
enum KnownAssistant {
  claude,
  chatGpt,
  vsCode,
  cursor,

  /// Un outil installé sur l'ordinateur (Claude Code, Cursor, VS Code…).
  localTool,
}

const _machine = {'localhost', '127.0.0.1', '::1'};

/// L'assistant reconnu pour [redirectUri], ou `null`. La requête (`?code=…`)
/// n'entre pas en compte ; un identifiant (`user@`), un fragment ou un
/// port sur un domaine public font refuser l'adresse.
KnownAssistant? recognizeAssistant(String redirectUri) {
  final uri = Uri.tryParse(redirectUri);
  if (uri == null || uri.userInfo.isNotEmpty || uri.hasFragment) return null;
  final path = uri.path;
  switch (uri.scheme) {
    case 'https' when !uri.hasPort:
      if ((uri.host == 'claude.ai' || uri.host == 'claude.com') &&
          path == '/api/mcp/auth_callback') {
        return KnownAssistant.claude;
      }
      if (uri.host == 'chatgpt.com' &&
          (path == '/connector_platform_oauth_redirect' ||
              path.startsWith('/connector/oauth/'))) {
        return KnownAssistant.chatGpt;
      }
      if (uri.host == 'vscode.dev' && path == '/redirect') {
        return KnownAssistant.vsCode;
      }
    case 'cursor':
      if (uri.host == 'anysphere.cursor-mcp' && path == '/oauth/callback') {
        return KnownAssistant.cursor;
      }
    case 'http':
      if (_machine.contains(uri.host)) return KnownAssistant.localTool;
  }
  return null;
}

/// Un accès accordé à un assistant.
final class AssistantGrant {
  const AssistantGrant({
    required this.clientId,
    required this.name,
    required this.grantedAt,
  });

  final String clientId;

  /// Le nom que le client s'est donné (vide s'il n'en a pas).
  final String name;
  final DateTime grantedAt;
}

/// Une demande d'accès, lue sur le serveur d'autorisation.
sealed class ConsentRequest {
  const ConsentRequest();
}

/// L'utilisateur doit trancher.
final class ConsentToDecide extends ConsentRequest {
  const ConsentToDecide({
    required this.clientName,
    required this.redirectUri,
    required this.email,
  });

  /// Le nom que le client se donne : jamais une preuve.
  final String clientName;

  /// L'adresse où le code sera remis : c'est elle qui identifie l'assistant.
  final String redirectUri;

  /// Le compte connecté, pour que l'utilisateur vérifie qui accorde.
  final String email;
}

/// Accès déjà accordé à ce client : le serveur rend directement l'adresse de
/// retour.
final class ConsentAlreadyGiven extends ConsentRequest {
  const ConsentAlreadyGiven(this.redirectUrl);

  final Uri redirectUrl;
}

abstract interface class AssistantRepository {
  /// Lit la demande d'accès [authorizationId].
  Future<ConsentRequest> fetchConsent(String authorizationId);

  /// Accorde l'accès ; rend l'adresse de retour de l'assistant, code compris.
  Future<Uri> approve(String authorizationId);

  /// Refuse l'accès ; rend l'adresse de retour (`error=access_denied`), ou
  /// `null` si le serveur n'en donne pas.
  Future<Uri?> deny(String authorizationId);

  /// Les accès accordés par l'utilisateur.
  Future<List<AssistantGrant>> listGrants();

  /// Retire l'accès de [clientId] ; ses jetons tombent aussitôt.
  Future<void> revoke(String clientId);
}
