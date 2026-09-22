/// Accès à l'agenda perso : lecture des instances, écriture des rdv, des
/// séries et de leurs exceptions.
///
/// Vocabulaire :
/// - un rdv ponctuel se crée, se modifie et se supprime par son id ;
/// - une **série** se modifie « en entier » depuis une de ses occurrences :
///   elle se décale d'autant que cette occurrence ([updateSeries]), elle ne
///   reprend jamais ses dates comme nouveau début ;
/// - une **occurrence** d'une série se modifie seule (elle devient un rdv à
///   part, rattaché à la série) ou se supprime seule (exception).
///
/// Invariants : seules des `AppException` en sortent ; le dépliage des
/// séries reste au worker, l'app ne fait que lire ses occurrences.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';

abstract interface class CalendarRepository {
  /// Instances de [from] (inclus) à [to] (exclu), au plus un trimestre.
  Future<List<AgendaItem>> fetchAgenda(DateTime from, DateTime to);

  /// Émet à chaque changement des rdv ou des occurrences visibles par
  /// l'utilisateur (temps réel) ; le compteur évite qu'un `==` avale un tick.
  Stream<int> watchChanges();

  Future<void> createEvent(EventDraft draft);

  /// Modifie un rdv ponctuel (ou le range dans un autre agenda).
  Future<void> updateEvent(String eventId, EventDraft draft);

  /// Modifie toute une série depuis l'occurrence qui commençait à
  /// [occurrenceStart] et que [draft] décrit après modification : la série
  /// se décale d'autant (jours et heure locale), prend la durée, le texte,
  /// la règle et l'agenda de [draft]. Avec [followWeekdays], les jours de
  /// répétition suivent l'écart de jours, compté par le serveur dans le
  /// fuseau de la série.
  Future<void> updateSeries({
    required String seriesId,
    required DateTime occurrenceStart,
    required EventDraft draft,
    required bool followWeekdays,
  });

  /// Modifie une seule occurrence d'une série : elle devient un rdv à part.
  Future<void> updateOccurrence({
    required String seriesId,
    required DateTime originalStart,
    required EventDraft draft,
  });

  /// Supprime un rdv ponctuel, une occurrence modifiée, ou toute une série.
  Future<void> deleteEvent(String eventId);

  /// Supprime une seule occurrence d'une série.
  Future<void> deleteOccurrence({
    required String seriesId,
    required DateTime originalStart,
  });
}
