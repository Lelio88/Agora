/// Accès à l'agenda perso : lecture des instances, écriture des rdv, des
/// séries et de leurs exceptions.
///
/// Vocabulaire :
/// - un rdv ponctuel se crée, se modifie et se supprime par son id ;
/// - une **série** se modifie « en entier » par l'id de sa ligne maîtresse ;
/// - une **occurrence** d'une série se modifie seule (elle devient un rdv à
///   part, rattaché à la série) ou se supprime seule (exception).
///
/// Invariants : seules des `AppException` en sortent ; le dépliage des
/// séries reste au worker, l'app ne fait que lire ses occurrences.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';

abstract interface class CalendarRepository {
  /// Identifiant de l'agenda natif par défaut de l'utilisateur.
  Future<String> defaultCalendarId();

  /// Instances de [from] (inclus) à [to] (exclu), au plus un trimestre.
  Future<List<AgendaItem>> fetchAgenda(DateTime from, DateTime to);

  /// Émet à chaque changement des rdv ou des occurrences visibles par
  /// l'utilisateur (temps réel) ; le compteur évite qu'un `==` avale un tick.
  Stream<int> watchChanges();

  Future<void> createEvent(EventDraft draft);

  /// Modifie un rdv ponctuel, ou toute une série par sa ligne maîtresse.
  Future<void> updateEvent(String eventId, EventDraft draft);

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
