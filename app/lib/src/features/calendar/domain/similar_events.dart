/// Rdv semblables : ce qu'une modification recopie sur les rdv ponctuels
/// qui reviennent sans être une série (un emploi du temps saisi séance par
/// séance, chacune avec son sujet).
///
/// Le serveur dit qui est semblable (`count_similar_events` : même agenda,
/// même titre, même jour de la semaine et même heure, à partir du rdv
/// ouvert) ; l'app dit quels champs recopier : ceux que l'utilisateur a
/// changés, et elle les lui montre sous la case avant qu'il enregistre.
///
/// Choix non évidents :
/// - jamais la date ni l'heure : chaque séance garde son horaire ;
/// - un texte se compare nettoyé (espaces autour retirés, vide = absent),
///   comme le serveur l'enregistre : rouvrir et enregistrer ne recopie rien ;
/// - une série n'a pas de semblables : elle a déjà « toute la série ».
///
/// Invariant : le nom de chaque [SimilarField] est le code que la RPC
/// `update_similar_events` attend dans `p_fields`.
library;

import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/event_draft.dart';

/// Champ qu'une modification peut recopier, dans l'ordre où on les cite.
enum SimilarField { title, location, description, visibility, calendar }

/// Vrai si [item] peut avoir des semblables : un rdv ponctuel seulement.
bool canHaveSimilar(AgendaItem item) => item.kind == InstanceKind.single;

/// Les champs de [draft] qui diffèrent de [item], hors date et heure, dans
/// l'ordre de [SimilarField].
Set<SimilarField> similarChanges(AgendaItem item, EventDraft draft) => {
  if (draft.title.trim() != item.title.trim()) SimilarField.title,
  if (_clean(draft.location) != _clean(item.location)) SimilarField.location,
  if (_clean(draft.description) != _clean(item.description))
    SimilarField.description,
  if (draft.visibility != item.visibility) SimilarField.visibility,
  if (draft.calendarId != item.calendarId) SimilarField.calendar,
};

String? _clean(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
