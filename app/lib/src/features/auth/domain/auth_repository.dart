/// Frontière d'authentification d'Agora : compte par e-mail et mot de passe,
/// confirmé par un **code à 6 chiffres** envoyé par e-mail.
///
/// Choix non évident : un code plutôt qu'un lien. Le lien imposerait des deep
/// links Android, une liste blanche de redirections, et d'ouvrir le mail sur
/// l'appareil même. Le code se lit n'importe où et se saisit dans l'app.
///
/// Invariants :
/// - toute méthode ne lève que des `AppException` (traduction dans `data/`) ;
/// - une adresse inconnue ne se distingue jamais d'un mauvais mot de passe,
///   et [requestPasswordReset] réussit même pour une adresse inconnue.
library;

import 'package:agora/src/features/auth/domain/app_user.dart';
import 'package:agora/src/features/auth/domain/left_behind_event.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Émet l'utilisateur courant, puis à chaque connexion ou déconnexion.
  Stream<AppUser?> watchCurrentUser();

  /// Crée le compte et envoie le code de confirmation. [locale] et
  /// [timezone] initialisent le profil (et la langue des e-mails).
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
    required String timezone,
  });

  /// Confirme l'adresse avec le code reçu ; ouvre la session.
  Future<void> verifySignUpCode({required String email, required String code});

  Future<void> resendSignUpCode({required String email});

  Future<void> signIn({required String email, required String password});

  /// Envoie un code de réinitialisation, si un compte utilise [email].
  Future<void> requestPasswordReset({required String email});

  /// Vérifie le code de réinitialisation (ce qui ouvre une session), puis
  /// enregistre [newPassword].
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> signOut();

  /// Rdv proposés à des groupes, qui leur resteraient si le compte était
  /// supprimé maintenant.
  Future<List<LeftBehindEvent>> proposedGroupEvents();

  /// Efface ces rdv. Rend leur nombre.
  Future<int> deleteProposedGroupEvents();

  /// Supprime définitivement le compte et ses données personnelles, puis
  /// ferme la session. Les groupes possédés sont transmis (voir la
  /// migration `account_deletion`). Les rdv proposés à un groupe lui
  /// restent : [proposedGroupEvents] les annonce,
  /// [deleteProposedGroupEvents] les efface.
  Future<void> deleteAccount();
}
