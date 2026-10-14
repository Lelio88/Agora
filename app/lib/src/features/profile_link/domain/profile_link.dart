/// Un lien de profil : ce qu'un membre partage de lui-même à quelqu'un qui
/// ouvre le lien ou scanne son QR code.
///
/// Choix non évidents :
/// - le niveau vit sur le LIEN (et non sur l'agenda) : chaque lien a son nom
///   (« Pour Marie ») et son niveau, comme un groupe a son niveau de partage.
///   La visibilité réglée sur un agenda ou un rdv reste un plafond, côté
///   serveur ;
/// - il n'y a que deux niveaux : un lien « invisible » n'aurait pas de sens,
///   on le supprime ;
/// - la copie reçue est figée : le lien ne donne jamais accès à l'agenda en
///   direct, et le supprimer ne reprend rien de ce qui a été copié.
library;

/// Ce que le lien laisse voir des rdv (avant plafonnement par les agendas).
enum ProfileLinkLevel {
  /// Titres et lieux.
  details,

  /// Des plages occupées, sans détail.
  busy;

  /// Le niveau du code reçu du serveur ; « occupé » si on ne le reconnaît pas,
  /// le moins bavard des deux.
  static ProfileLinkLevel fromCode(String? code) =>
      code == 'details' ? details : busy;
}

final class ProfileLink {
  const ProfileLink({
    required this.code,
    required this.label,
    required this.level,
    required this.createdAt,
  });

  /// Le secret du lien : 8 caractères.
  final String code;

  /// Le nom que le propriétaire lui a donné.
  final String label;

  final ProfileLinkLevel level;
  final DateTime createdAt;
}

/// Un code de lien de profil plausible (8 caractères, alphabet sans
/// ambiguïté, casse ignorée) : tout le reste est ignoré avant le serveur.
bool looksLikeProfileLinkCode(String code) =>
    RegExp(r'^[A-HJ-NP-Za-hj-np-z2-9]{8}$').hasMatch(code.trim());

/// Longueur maximale du nom d'un lien (celle du serveur).
const profileLinkLabelMaxLength = 60;
