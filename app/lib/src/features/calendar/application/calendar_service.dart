/// Actions sur l'agenda : créer, modifier, supprimer, avec le choix « cette
/// occurrence » ou « toute la série » pour un rdv récurrent.
///
/// [EditTarget] porte ce choix. Pour un rdv ponctuel, les deux portées se
/// confondent : on modifie ou supprime le rdv lui-même.
///
/// Choix non évidents :
/// - chaque action réussie invalide l'agenda elle-même, sans attendre le
///   temps réel. Celui-ci peut manquer (pile locale sans Realtime,
///   coupure), et l'utilisateur doit voir sa propre modification tout de
///   suite ;
/// - « toute la série » depuis une occurrence : ce que l'utilisateur a
///   changé dans les dates s'applique en ÉCART au créneau d'origine de
///   l'occurrence, que le serveur reporte sur la série (`update_series`).
///   Sans changement de date, la série ne bouge pas, même depuis une
///   occurrence déjà déplacée ;
/// - si l'utilisateur n'a pas touché aux jours de répétition, ils suivent
///   le décalage (un rdv du mardi glissé au mercredi se répète le
///   mercredi). L'écart de jours est compté par le serveur, dans le fuseau
///   de la série : compté ici, dans celui de l'appareil, il pouvait
///   différer près de minuit pour un utilisateur en voyage.
library;

import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/application/group_event_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/features/calendar/domain/recurrence_rule.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EditScope { occurrence, series }

/// Instance visée par une modification ou une suppression, et sa portée.
final class EditTarget {
  const EditTarget._(this.item, this.scope);

  const EditTarget.occurrence(AgendaItem item)
    : this._(item, EditScope.occurrence);
  const EditTarget.series(AgendaItem item) : this._(item, EditScope.series);

  final AgendaItem item;
  final EditScope scope;

  /// Vrai quand l'action ne touche qu'une occurrence d'une série.
  bool get isSingleOccurrence =>
      item.isRecurring && scope == EditScope.occurrence;

  /// Ligne à supprimer quand l'action porte sur le rdv entier : la série
  /// pour une occurrence, le rdv lui-même sinon. (Modifier toute une série
  /// passe par `updateSeries`, qui la décale.)
  String get wholeEventId => item.seriesId ?? item.eventId;
}

final class CalendarService {
  const CalendarService(this._repository, this._onChanged);

  final CalendarRepository _repository;

  /// Appelé après chaque action réussie (invalide l'agenda).
  final void Function() _onChanged;

  Future<void> create(EventDraft draft) =>
      _then(_repository.createEvent(draft));

  Future<void> save({required EditTarget target, required EventDraft draft}) {
    if (target.isSingleOccurrence) {
      return _then(
        _repository.updateOccurrence(
          seriesId: target.item.seriesId!,
          originalStart: target.item.originalStart!,
          draft: draft,
        ),
      );
    }
    final item = target.item;
    if (item.isRecurring) {
      final slot = item.originalStart ?? item.start;
      return _then(
        _repository.updateSeries(
          seriesId: item.seriesId!,
          occurrenceStart: slot,
          draft: seriesDraft(item, draft),
          followWeekdays: weekdaysUntouched(item, draft),
        ),
      );
    }
    return _then(_repository.updateEvent(item.eventId, draft));
  }

  /// [draft] (saisi sur l'occurrence [item]) ramené au créneau d'origine de
  /// l'occurrence : l'écart que l'utilisateur a saisi, appliqué à ce créneau.
  static EventDraft seriesDraft(AgendaItem item, EventDraft draft) {
    final slot = item.originalStart ?? item.start;
    final start = slot.add(draft.start.difference(item.start));
    return draft.copyWith(
      start: start,
      end: start.add(draft.end.difference(draft.start)),
    );
  }

  /// Vrai si l'utilisateur a laissé les jours de répétition tels quels (ils
  /// suivront alors le décalage de la série).
  static bool weekdaysUntouched(AgendaItem item, EventDraft draft) {
    final rule = draft.recurrence;
    if (rule == null || rule.weekdays.isEmpty || item.rrule == null) {
      return false;
    }
    final original = RecurrenceRule.parse(item.rrule!);
    return original != null &&
        original.weekdays.length == rule.weekdays.length &&
        original.weekdays.containsAll(rule.weekdays);
  }

  Future<void> delete(EditTarget target) {
    if (target.isSingleOccurrence) {
      return _then(
        _repository.deleteOccurrence(
          seriesId: target.item.seriesId!,
          originalStart: target.item.originalStart!,
        ),
      );
    }
    return _then(_repository.deleteEvent(target.wholeEventId));
  }

  /// Règle ce que les groupes voient de l'instance [item] : d'une série
  /// entière depuis l'une de ses occurrences, d'une occurrence modifiée
  /// seule (c'est une ligne à part).
  Future<void> setVisibility(AgendaItem item, EventVisibility? visibility) =>
      _then(_repository.setEventVisibility(item.eventId, visibility));

  /// Répond à l'instance [item] d'un rdv de groupe ; `null` retire la
  /// réponse.
  Future<void> respond(AgendaItem item, ResponseStatus? status) =>
      _then(_repository.respond(item.responseKey, status));

  Future<void> _then(Future<void> action) async {
    await action;
    _onChanged();
  }
}

/// Chaque action relit l'agenda, et la fiche ouverte d'un rdv de groupe
/// avec ses réponses.
final calendarServiceProvider = Provider<CalendarService>(
  (ref) => CalendarService(ref.watch(calendarRepositoryProvider), () {
    ref
      ..invalidate(agendaProvider)
      ..invalidate(groupEventProvider)
      ..invalidate(eventResponsesProvider);
  }),
);
