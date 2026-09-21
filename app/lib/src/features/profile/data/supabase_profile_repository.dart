/// [ProfileRepository] adossé à la table `profiles` (PostgREST).
///
/// Les droits du serveur bornent ce qui est modifiable : `display_name`,
/// `timezone`, `locale` (et `avatar_url`), sur sa seule ligne. Un changement
/// de `locale` est recopié côté serveur dans les métadonnées lues par les
/// gabarits d'e-mail. Rien à faire ici pour cela.
library;

import 'package:agora/src/exceptions/app_exception.dart';
import 'package:agora/src/exceptions/network_errors.dart';
import 'package:agora/src/features/profile/domain/profile.dart';
import 'package:agora/src/features/profile/domain/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> fetchProfile(String userId) => _guard(() async {
    final row = await _client
        .from('profiles')
        .select('id, display_name, timezone, locale')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Profile(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      timezone: row['timezone'] as String,
      language: AppLanguage.fromCode(row['locale'] as String?),
    );
  });

  @override
  Future<void> updateProfile(Profile profile) => _guard(
    () => _client
        .from('profiles')
        .update({
          'display_name': profile.displayName.trim(),
          'timezone': profile.timezone,
          'locale': profile.language.name,
        })
        .eq('id', profile.id),
  );

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (error) {
      // Message levé par private.check_profile_timezone (SQLSTATE 22023).
      if (error.message == 'invalid_timezone') {
        throw const InvalidTimezoneException();
      }
      throw looksLikeNetworkError(error.message)
          ? const NetworkException()
          : const UnknownException();
    } on Exception catch (error) {
      throw looksLikeNetworkError(error.toString())
          ? const NetworkException()
          : const UnknownException();
    }
  }
}
