/// [ProfileLinkRepository] sur PostgREST.
///
/// Choix non évidents :
/// - un lien se crée par la RPC `create_profile_link` (le code est tiré côté
///   serveur, et la table n'accorde ni insertion ni mise à jour) ; la liste
///   se lit et se supprime en direct, la RLS limitant aux liens du
///   propriétaire ;
/// - ouvrir un lien ne passe que par `import_profile` : l'app ne lit jamais
///   l'agenda d'autrui, elle ne reçoit que l'identifiant du proche créé ;
/// - un lien inconnu ou supprimé revient du serveur par un résultat nul (pas
///   par une exception, qui annulerait la trace de l'échec servant à limiter
///   le débit) : c'est ici qu'il devient [InvalidProfileLinkException].
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/features/profile_link/domain/profile_link_repository.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseProfileLinkRepository implements ProfileLinkRepository {
  const SupabaseProfileLinkRepository(this._client);

  final SupabaseClient _client;

  static const _columns = 'code, label, share_level, created_at';

  ProfileLink _toLink(Map<String, dynamic> row) => ProfileLink(
    code: row['code'] as String,
    label: row['label'] as String,
    level: ProfileLinkLevel.fromCode(row['share_level'] as String?),
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  @override
  Future<List<ProfileLink>> fetchMine() => guardPostgrest(() async {
    final rows = await _client
        .from('profile_links')
        .select(_columns)
        .order('created_at', ascending: false);
    return [for (final row in rows) _toLink(row)];
  });

  @override
  Future<ProfileLink> create({
    required String label,
    required ProfileLinkLevel level,
  }) => guardPostgrest(() async {
    final code = await _client.rpc<String>(
      'create_profile_link',
      params: {'p_label': label, 'p_share_level': level.name},
    );
    final row = await _client
        .from('profile_links')
        .select(_columns)
        .eq('code', code)
        .single();
    return _toLink(row);
  });

  @override
  Future<void> revoke(String code) => guardPostgrest(
    () => _client.from('profile_links').delete().eq('code', code),
  );

  @override
  Future<String> previewName(String code) => guardPostgrest(() async {
    final name = await _client.rpc<String?>(
      'profile_link_preview',
      params: {'p_code': code},
    );
    return name ?? (throw const InvalidProfileLinkException());
  });

  @override
  Future<String> importProfile(String code) => guardPostgrest(() async {
    final calendarId = await _client.rpc<String?>(
      'import_profile',
      params: {'p_code': code},
    );
    return calendarId ?? (throw const InvalidProfileLinkException());
  });
}
