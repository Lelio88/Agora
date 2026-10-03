/// [AssistantRepository] sur le serveur OAuth 2.1 de GoTrue (client
/// `auth.oauth` de supabase_flutter).
///
/// Choix non évidents :
/// - lire la demande, la trancher, lister et retirer les accès se fait avec la
///   session de l'application : ces routes passent par la garde du worker,
///   qui refuse les jetons d'assistant mais laisse passer l'app ;
/// - GoTrue n'accepte la décision que depuis l'origine du Site URL : c'est
///   pourquoi le consentement vit dans l'app **web** ;
/// - un accès déjà retiré (`oauth_consent_not_found`) compte comme retiré.
///
/// Invariant : seules des `AppException` sortent du dépôt.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:agora/src/features/auth/data/auth_error_translator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseAssistantRepository implements AssistantRepository {
  const SupabaseAssistantRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ConsentRequest> fetchConsent(String authorizationId) =>
      _guard(() async {
        final response = await _client.auth.oauth.getAuthorizationDetails(
          authorizationId,
        );
        return switch (response) {
          OAuthAuthorizationDetailsResponse(
            :final client,
            :final redirectUri,
            :final user,
          ) =>
            ConsentToDecide(
              clientName: client.clientName?.trim() ?? '',
              redirectUri: redirectUri,
              email: user.email ?? '',
            ),
          OAuthAuthorizationRedirectResponse(:final redirectUrl) =>
            ConsentAlreadyGiven(Uri.parse(redirectUrl)),
        };
      });

  @override
  Future<Uri> approve(String authorizationId) => _guard(() async {
    final response = await _client.auth.oauth.approveAuthorization(
      authorizationId,
    );
    final redirect = response.redirectUrl;
    if (redirect == null) throw const UnknownException();
    return Uri.parse(redirect);
  });

  @override
  Future<Uri?> deny(String authorizationId) => _guard(() async {
    final response = await _client.auth.oauth.denyAuthorization(
      authorizationId,
    );
    final redirect = response.redirectUrl;
    return redirect == null ? null : Uri.tryParse(redirect);
  });

  @override
  Future<List<AssistantGrant>> listGrants() => _guard(() async {
    final grants = await _client.auth.oauth.listGrants();
    return [
      for (final grant in grants)
        AssistantGrant(
          clientId: grant.client.clientId,
          name: grant.client.clientName?.trim() ?? '',
          grantedAt: grant.grantedAt,
        ),
    ]..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
  });

  @override
  Future<void> revoke(String clientId) => _guard(() async {
    try {
      await _client.auth.oauth.revokeGrant(clientId);
    } on AuthException catch (error) {
      if (error.code != 'oauth_consent_not_found') rethrow;
    }
  });
}

Future<T> _guard<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on AppException {
    rethrow;
  } on AuthException catch (error) {
    throw switch (error.code) {
      'oauth_authorization_not_found' => const ConsentExpiredException(),
      'feature_disabled' => const AssistantsUnavailableException(),
      _ => translateAuthError(error),
    };
  } on Exception catch (error) {
    throw looksLikeNetworkError(error.toString())
        ? const NetworkException()
        : const UnknownException();
  }
}
