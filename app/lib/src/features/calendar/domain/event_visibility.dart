/// Niveau de visibilité d'un rdv ou d'un agenda pour les autres membres d'un
/// groupe, tel que la base le connaît (`public.visibility`).
///
/// Sur un rdv ou un agenda, `null` signifie « hérite » ; seuls [busy] et
/// [invisible] s'y posent, jamais [details] (contrainte serveur).
library;

enum EventVisibility {
  details,
  busy,
  invisible;

  static EventVisibility? fromCode(String? code) =>
      values.where((v) => v.name == code).firstOrNull;
}
