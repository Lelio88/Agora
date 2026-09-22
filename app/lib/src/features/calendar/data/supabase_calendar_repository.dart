/// [CalendarRepository] sur PostgREST et Realtime.
///
/// Choix non évidents :
/// - la lecture passe par la RPC `my_agenda` : elle renvoie des instances
///   déjà dépliées (par le worker) et jamais la ligne maîtresse d'une série ;
/// - modifier une occurrence passe par la RPC `replace_occurrence`, qui crée
///   une ligne à part rattachée à la série ; le serveur masque aussitôt
///   l'occurrence dépliée ;
/// - la fiche d'un rdv de groupe lit sa ligne directement (la RLS la rend
///   lisible aux membres) et en tire l'instance voulue ; les réponses
///   s'écrivent par la RPC `respond_to_event`, seule écriture permise ;
/// - le temps réel ne transporte aucun contenu : à chaque changement de
///   `events` ou de `series_expansions` (le worker a redéplié une série),
///   on relit. `event_occurrences` n'est pas publiée : Realtime diffuse les
///   suppressions à tous les abonnés sans RLS, et sa clé porte l'horaire.
///
/// Invariant : aucune `PostgrestException` ne sort d'ici sans traduction.
library;

import 'dart:async';

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/supabase/postgrest_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseCalendarRepository implements CalendarRepository {
  const SupabaseCalendarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AgendaItem>> fetchAgenda(DateTime from, DateTime to) =>
      _guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'my_agenda',
          params: {
            'p_from': from.toUtc().toIso8601String(),
            'p_to': to.toUtc().toIso8601String(),
          },
        );
        return rows
            .cast<Map<String, dynamic>>()
            .map(_toAgendaItem)
            .toList(growable: false);
      });

  @override
  Stream<int> watchChanges() {
    final controller = StreamController<int>();
    var ticks = 0;
    final channel = _client.channel('agenda-changes');
    for (final table in ['events', 'series_expansions']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => controller.add(++ticks),
      );
    }
    channel.subscribe();
    controller.onCancel = () => _client.removeChannel(channel);
    return controller.stream;
  }

  @override
  Future<void> createEvent(EventDraft draft) =>
      _guard(() => _client.from('events').insert(_toRow(draft)));

  @override
  Future<void> updateEvent(String eventId, EventDraft draft) => _guard(
    () => _client.from('events').update(_toRow(draft)).eq('id', eventId),
  );

  @override
  Future<void> updateSeries({
    required String seriesId,
    required DateTime occurrenceStart,
    required EventDraft draft,
    required bool followWeekdays,
  }) => _guard(
    // La série se décale côté serveur, dans son fuseau : l'app ne connaît
    // pas sa ligne maîtresse, seulement l'occurrence touchée.
    () => _client.rpc<void>(
      'update_series',
      params: {
        'p_series_id': seriesId,
        'p_occurrence_start': occurrenceStart.toUtc().toIso8601String(),
        'p_calendar_id': draft.calendarId,
        'p_title': draft.title.trim(),
        'p_location': _nullIfBlank(draft.location),
        'p_description': _nullIfBlank(draft.description),
        'p_starts_at': draft.start.toUtc().toIso8601String(),
        'p_ends_at': draft.end.toUtc().toIso8601String(),
        'p_all_day': draft.isAllDay,
        'p_rrule': draft.rrule,
        'p_visibility': draft.visibility?.name,
        'p_follow_weekdays': followWeekdays,
      },
    ),
  );

  @override
  Future<void> updateOccurrence({
    required String seriesId,
    required DateTime originalStart,
    required EventDraft draft,
  }) => _guard(
    // RPC plutôt qu'un upsert : la clé (series_id, recurrence_id) est un
    // index partiel, que Postgres refuse comme cible d'ON CONFLICT.
    () => _client.rpc<void>(
      'replace_occurrence',
      params: {
        'p_series_id': seriesId,
        'p_original_start': originalStart.toUtc().toIso8601String(),
        'p_title': draft.title.trim(),
        'p_location': _nullIfBlank(draft.location),
        'p_description': _nullIfBlank(draft.description),
        'p_starts_at': draft.start.toUtc().toIso8601String(),
        'p_ends_at': draft.end.toUtc().toIso8601String(),
        'p_all_day': draft.isAllDay,
        'p_visibility': draft.visibility?.name,
      },
    ),
  );

  @override
  Future<void> deleteEvent(String eventId) =>
      _guard(() => _client.from('events').delete().eq('id', eventId));

  @override
  Future<void> deleteOccurrence({
    required String seriesId,
    required DateTime originalStart,
  }) => _guard(
    () => _client.rpc<void>(
      'delete_occurrence',
      params: {
        'p_series_id': seriesId,
        'p_original_start': originalStart.toUtc().toIso8601String(),
      },
    ),
  );

  @override
  Future<void> setEventVisibility(
    String eventId,
    EventVisibility? visibility,
  ) => _guard(
    () => _client.rpc<void>(
      'set_event_visibility',
      params: {'p_event_id': eventId, 'p_visibility': visibility?.name},
    ),
  );

  @override
  Future<GroupEventInstance?> fetchInstance(
    String eventId, {
    DateTime? start,
  }) => _guard(() async {
    final row = await _client
        .from('events')
        .select(
          'id, calendar_id, series_id, recurrence_id, title, location, '
          'description, starts_at, ends_at, all_day, timezone, rrule, '
          'visibility, created_by',
        )
        .eq('id', eventId)
        .maybeSingle();
    if (row == null) return null;
    final seriesId = row['series_id'] as String?;
    // Une occurrence modifiée porte la règle de sa série (comme my_agenda).
    final masterRule = seriesId == null
        ? null
        : (await _client
                  .from('events')
                  .select('rrule')
                  .eq('id', seriesId)
                  .maybeSingle())?['rrule']
              as String?;
    return (
      item: _instanceOf(row, start: start, masterRule: masterRule),
      createdBy: row['created_by'] as String?,
    );
  });

  /// L'instance voulue d'une ligne d'`events` : une occurrence de série
  /// commence à [start] et dure ce que dure la série.
  static AgendaItem _instanceOf(
    Map<String, dynamic> row, {
    DateTime? start,
    String? masterRule,
  }) {
    final id = row['id'] as String;
    final rule = row['rrule'] as String?;
    final rowStart = _timestamp(row['starts_at'])!;
    final rowEnd = _timestamp(row['ends_at'])!;
    final isSeries = rule != null;
    final instanceStart = isSeries ? (start?.toUtc() ?? rowStart) : rowStart;
    return AgendaItem(
      eventId: id,
      seriesId: isSeries ? id : row['series_id'] as String?,
      originalStart: isSeries
          ? instanceStart
          : _timestamp(row['recurrence_id']),
      calendarId: row['calendar_id'] as String,
      title: row['title'] as String,
      location: row['location'] as String?,
      description: row['description'] as String?,
      start: instanceStart,
      end: instanceStart.add(rowEnd.difference(rowStart)),
      isAllDay: row['all_day'] as bool,
      timezone: row['timezone'] as String,
      rrule: rule ?? masterRule,
      visibility: EventVisibility.fromCode(row['visibility'] as String?),
    );
  }

  @override
  Future<List<EventResponse>> fetchResponses(ResponseKey key) =>
      _guard(() async {
        final query = _client
            .from('event_responses')
            .select('user_id, status')
            .eq('event_id', key.eventId);
        final occurrence = key.occurrenceStart;
        final rows = occurrence == null
            ? await query.isFilter('occurrence_start', null)
            : await query.eq(
                'occurrence_start',
                occurrence.toUtc().toIso8601String(),
              );
        return [
          for (final row in rows)
            if (ResponseStatus.fromCode(row['status'] as String?)
                case final status?)
              EventResponse(userId: row['user_id'] as String, status: status),
        ];
      });

  @override
  Future<void> respond(ResponseKey key, ResponseStatus? status) => _guard(
    () => _client.rpc<void>(
      'respond_to_event',
      params: {
        'p_event_id': key.eventId,
        'p_occurrence_start': key.occurrenceStart?.toUtc().toIso8601String(),
        'p_status': status?.code,
      },
    ),
  );

  static Map<String, dynamic> _toRow(EventDraft draft) => {
    'calendar_id': draft.calendarId,
    'title': draft.title.trim(),
    'location': _nullIfBlank(draft.location),
    'description': _nullIfBlank(draft.description),
    'starts_at': draft.start.toUtc().toIso8601String(),
    'ends_at': draft.end.toUtc().toIso8601String(),
    'all_day': draft.isAllDay,
    'timezone': draft.timezone,
    'rrule': draft.rrule,
    'visibility': draft.visibility?.name,
  };

  static AgendaItem _toAgendaItem(Map<String, dynamic> row) => AgendaItem(
    eventId: row['event_id'] as String,
    seriesId: row['series_id'] as String?,
    originalStart: _timestamp(row['original_start']),
    calendarId: row['calendar_id'] as String,
    title: row['title'] as String,
    location: row['location'] as String?,
    description: row['description'] as String?,
    start: _timestamp(row['starts_at'])!,
    end: _timestamp(row['ends_at'])!,
    isAllDay: row['all_day'] as bool,
    timezone: row['timezone'] as String,
    rrule: row['rrule'] as String?,
    visibility: EventVisibility.fromCode(row['visibility'] as String?),
    myResponse: ResponseStatus.fromCode(row['my_response'] as String?),
  );

  static DateTime? _timestamp(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static Future<T> _guard<T>(Future<T> Function() body) => guardPostgrest(body);
}
