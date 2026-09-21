/// Actions sur l'agenda : créer, modifier, supprimer, avec le choix « cette
/// occurrence » ou « toute la série » pour un rdv récurrent.
///
/// [EditTarget] porte ce choix. Pour un rdv ponctuel, les deux portées se
/// confondent : on modifie ou supprime le rdv lui-même.
///
/// Choix non évident : chaque action réussie invalide l'agenda elle-même,
/// sans attendre le temps réel. Celui-ci peut manquer (pile locale sans
/// Realtime, coupure), et l'utilisateur doit voir sa propre modification
/// tout de suite.
library;

import 'package:agora/src/features/calendar/application/agenda_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';
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

  /// Ligne à modifier ou supprimer quand l'action porte sur le rdv entier :
  /// la série pour une occurrence, le rdv lui-même sinon.
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
    return _then(_repository.updateEvent(target.wholeEventId, draft));
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

  Future<void> _then(Future<void> action) async {
    await action;
    _onChanged();
  }
}

final calendarServiceProvider = Provider<CalendarService>(
  (ref) => CalendarService(
    ref.watch(calendarRepositoryProvider),
    () => ref.invalidate(agendaProvider),
  ),
);
