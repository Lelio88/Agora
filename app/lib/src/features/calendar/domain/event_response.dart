/// Réponse à un rdv de groupe : présent, peut-être, absent.
///
/// Une réponse vaut pour une **instance** ([ResponseKey]) : un rdv ponctuel
/// ou une occurrence modifiée se répond en entier, une série occurrence par
/// occurrence (par son créneau d'origine). Changer l'horaire d'une série
/// efface les réponses de ses occurrences, côté serveur.
library;

enum ResponseStatus {
  yes('yes'),
  maybe('maybe'),
  no('no');

  const ResponseStatus(this.code);

  final String code;

  static ResponseStatus? fromCode(String? code) => switch (code) {
    'yes' => yes,
    'maybe' => maybe,
    'no' => no,
    _ => null,
  };
}

/// La réponse d'un membre.
final class EventResponse {
  const EventResponse({required this.userId, required this.status});

  final String userId;
  final ResponseStatus status;
}

/// L'instance à laquelle on répond : le rdv, et pour une occurrence de
/// série son créneau d'origine (voir `AgendaItem.responseKey`).
final class ResponseKey {
  /// Le créneau est ramené en UTC : `DateTime.==` distingue un même instant
  /// en heure locale et en UTC.
  ResponseKey(this.eventId, [DateTime? occurrenceStart])
    : occurrenceStart = occurrenceStart?.toUtc();

  final String eventId;
  final DateTime? occurrenceStart;

  @override
  bool operator ==(Object other) =>
      other is ResponseKey &&
      other.eventId == eventId &&
      other.occurrenceStart == occurrenceStart;

  @override
  int get hashCode => Object.hash(eventId, occurrenceStart);
}
