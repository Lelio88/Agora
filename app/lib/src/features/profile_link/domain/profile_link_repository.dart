/// Accès aux liens de profil : les siens (créer, lire, supprimer), et l'ouverture
/// d'un lien reçu (le nom de la personne, puis la copie de son agenda).
library;

import 'package:agora/src/features/profile_link/domain/profile_link.dart';

abstract interface class ProfileLinkRepository {
  /// Les liens de l'utilisateur, le plus récent d'abord.
  Future<List<ProfileLink>> fetchMine();

  /// Crée un lien nommé [label], au niveau [level], pour les seuls agendas
  /// [calendarIds] (au moins un).
  Future<ProfileLink> create({
    required String label,
    required ProfileLinkLevel level,
    required List<String> calendarIds,
  });

  /// Supprime le lien : il n'ouvre plus rien. Ce qui a déjà été copié reste.
  Future<void> revoke(String code);

  /// Le nom de la personne derrière [code] ; échoue si le lien est inconnu
  /// ou supprimé (sans dire lequel).
  Future<String> previewName(String code);

  /// Ouvre le lien : crée (ou rafraîchit) le proche de la personne et rend
  /// l'identifiant de cet agenda.
  Future<String> importProfile(String code);
}
