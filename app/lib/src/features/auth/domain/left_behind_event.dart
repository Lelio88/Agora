/// Rdv qu'une suppression de compte laisserait derrière elle : proposé à un
/// groupe, il lui appartient et lui reste, sans auteur mais avec son texte.
///
/// Sert uniquement à l'annoncer avant la suppression, et à proposer de les
/// effacer d'abord. Le groupe est nommé pour que la personne reconnaisse où
/// le rdv restera.
library;

final class LeftBehindEvent {
  const LeftBehindEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.groupName,
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final String groupName;
}
