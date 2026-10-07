/// [TravelRepository] adossé aux tables `travel_settings` et
/// `event_travel_modes` (PostgREST).
///
/// La RLS borne tout aux lignes de l'utilisateur connecté, et `user_id` y
/// vaut `auth.uid()` par défaut : les upserts ne l'envoient pas. Poser le
/// domicile n'envoie que ses colonnes : l'upsert ne réécrit pas le mode
/// préféré ni l'affichage dans l'agenda.
library;

import 'package:agora/src/features/directions/domain/address.dart';
import 'package:agora/src/features/directions/domain/travel.dart';
import 'package:agora/src/features/directions/domain/travel_repository.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseTravelRepository implements TravelRepository {
  const SupabaseTravelRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<TravelSettings?> fetchSettings(String userId) =>
      guardPostgrest(() async {
        final row = await _client
            .from('travel_settings')
            .select(
              'home_address, home_lon, home_lat, travel_mode, show_in_agenda',
            )
            .eq('user_id', userId)
            .maybeSingle();
        if (row == null) return null;
        return TravelSettings(
          home: Address(
            label: row['home_address'] as String,
            longitude: (row['home_lon'] as num).toDouble(),
            latitude: (row['home_lat'] as num).toDouble(),
          ),
          preference: TravelPreference.fromCode(row['travel_mode'] as String?),
          showInAgenda: row['show_in_agenda'] as bool? ?? true,
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

  @override
  Future<void> savePreferences(
    String userId, {
    required TravelPreference preference,
    required bool showInAgenda,
  }) => guardPostgrest(
    () => _client
        .from('travel_settings')
        .update({
          'travel_mode': preference.name,
          'show_in_agenda': showInAgenda,
        })
        .eq('user_id', userId),
  );

  @override
  Future<Map<String, TravelChoice>> fetchChoices(String userId) =>
      guardPostgrest(() async {
        final rows = await _client
            .from('event_travel_modes')
            .select('event_id, mode')
            .eq('user_id', userId);
        return {
          for (final row in rows)
            row['event_id'] as String: ?TravelChoice.fromCode(
              row['mode'] as String?,
            ),
        };
      });

  @override
  Future<void> setChoice(String eventId, TravelChoice choice) => guardPostgrest(
    () => _client.from('event_travel_modes').upsert({
      'event_id': eventId,
      'mode': choice.name,
    }, onConflict: 'user_id,event_id'),
  );
}
