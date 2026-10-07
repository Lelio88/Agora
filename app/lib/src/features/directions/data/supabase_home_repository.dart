/// [HomeRepository] adossé à la table `travel_settings` (PostgREST).
///
/// La RLS borne tout à la ligne de l'utilisateur connecté, et `user_id` y
/// vaut `auth.uid()` par défaut : l'upsert ne l'envoie pas.
library;

import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/home_repository.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseHomeRepository implements HomeRepository {
  const SupabaseHomeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Address?> fetchHome(String userId) => guardPostgrest(() async {
    final row = await _client
        .from('travel_settings')
        .select('home_address, home_lon, home_lat')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Address(
      label: row['home_address'] as String,
      longitude: (row['home_lon'] as num).toDouble(),
      latitude: (row['home_lat'] as num).toDouble(),
    );
  });

  @override
  Future<void> saveHome(Address home) => guardPostgrest(
    () => _client.from('travel_settings').upsert({
      'home_address': home.label,
      'home_lon': home.longitude,
      'home_lat': home.latitude,
    }, onConflict: 'user_id'),
  );

  @override
  Future<void> deleteHome(String userId) => guardPostgrest(
    () => _client.from('travel_settings').delete().eq('user_id', userId),
  );
}
