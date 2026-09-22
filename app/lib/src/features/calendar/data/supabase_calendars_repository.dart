/// [CalendarsRepository] sur PostgREST.
///
/// Choix non évidents :
/// - la préférence d'affichage vient avec l'agenda, par jointure sur
///   `calendar_preferences` (la RLS n'y laisse que celles de l'utilisateur) ;
/// - la suppression passe par la RPC `delete_calendar` : le DELETE direct
///   est retiré, pour que le dernier agenda natif ne parte jamais ;
/// - masquer un agenda est un upsert sur (utilisateur, agenda).
library;

import 'package:agora/src/features/calendar/data/postgrest_errors.dart';
import 'package:agora/src/features/calendar/domain/calendars_repository.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseCalendarsRepository implements CalendarsRepository {
  const SupabaseCalendarsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<UserCalendar>> fetchCalendars() => guardPostgrest(() async {
    final rows = await _client
        .from('calendars')
        .select(
          'id, name, color, visibility, kind, group_id, '
          'calendar_preferences(hidden)',
        )
        .order('created_at', ascending: true);
    return rows.map(_toCalendar).toList(growable: false);
  });

  @override
  Future<void> createCalendar(CalendarDraft draft) =>
      guardPostgrest(() => _client.from('calendars').insert(_toRow(draft)));

  @override
  Future<void> updateCalendar(String calendarId, CalendarDraft draft) =>
      guardPostgrest(
        () => _client
            .from('calendars')
            .update(_toRow(draft))
            .eq('id', calendarId),
      );

  @override
  Future<void> deleteCalendar(String calendarId) => guardPostgrest(
    () => _client.rpc<void>(
      'delete_calendar',
      params: {'p_calendar_id': calendarId},
    ),
  );

  @override
  Future<void> setHidden(String calendarId, {required bool hidden}) =>
      guardPostgrest(
        () => _client.from('calendar_preferences').upsert({
          'calendar_id': calendarId,
          'hidden': hidden,
        }, onConflict: 'user_id,calendar_id'),
      );

  @override
  Future<int> countEvents(String calendarId) => guardPostgrest(
    () => _client
        .from('events')
        .count()
        .eq('calendar_id', calendarId)
        // Une occurrence modifiée est une ligne à part de sa série.
        .isFilter('series_id', null),
  );

  static Map<String, dynamic> _toRow(CalendarDraft draft) => {
    'name': draft.name.trim(),
    'color': draft.colorHex,
    'visibility': draft.visibility?.name,
  };

  static UserCalendar _toCalendar(Map<String, dynamic> row) {
    final preferences = (row['calendar_preferences'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return UserCalendar(
      id: row['id'] as String,
      name: row['name'] as String,
      kind: row['kind'] == 'ics' ? CalendarKind.ics : CalendarKind.native,
      colorHex: row['color'] as String?,
      visibility: EventVisibility.fromCode(row['visibility'] as String?),
      groupId: row['group_id'] as String?,
      hidden: preferences.any((p) => p['hidden'] == true),
    );
  }
}
