/// Le bot Discord vu de l'app : le compte Discord relié à celui de
/// l'utilisateur, et le salon relié à un groupe avec ses réglages.
///
/// Choix non évidents :
/// - le compte Discord est une identité de connexion (liaison OAuth par
///   GoTrue), pas une ligne d'une table d'Agora : l'app ne le lit que dans
///   la session ;
/// - un salon ne se relie PAS depuis l'app : l'app crée un code, et c'est
///   la commande `/relier` tapée dans le salon qui le relie. Discord seul
///   sait qui peut gérer ce salon.
///
/// Invariant : seules des `AppException` sortent du dépôt.
library;

/// Le compte Discord relié.
final class DiscordAccount {
  const DiscordAccount({required this.name});

  /// Nom à afficher (nom global, ou identifiant Discord à défaut).
  final String name;
}

/// Fréquence du récap publié dans le salon.
enum DiscordRecap {
  off('off'),
  daily('daily'),
  weekly('weekly');

  const DiscordRecap(this.code);

  final String code;

  static DiscordRecap fromCode(String? code) => values.firstWhere(
    (value) => value.code == code,
    orElse: () => DiscordRecap.off,
  );
}

/// Délais de rappel proposés, en minutes (le serveur n'accepte qu'eux).
const discordReminderChoices = [15, 60, 1440];

/// Le salon relié à un groupe, et ce que le bot y publie.
final class DiscordChannel {
  const DiscordChannel({
    required this.groupId,
    required this.channelName,
    required this.timezone,
    required this.recap,
    required this.recapWeekday,
    required this.recapHour,
    this.reminderMinutes,
  });

  final String groupId;

  /// Nom du salon au moment de la liaison (vide si Discord ne l'a pas dit).
  final String channelName;

  /// Fuseau des récaps : celui de la personne qui a relié le salon.
  final String timezone;
  final DiscordRecap recap;

  /// 1 = lundi … 7 = dimanche, pour un récap hebdomadaire.
  final int recapWeekday;

  /// Heure du récap, 0 à 23, dans le fuseau de la personne qui a relié.
  final int recapHour;

  /// `null` : pas de rappel.
  final int? reminderMinutes;

  DiscordChannel copyWith({
    DiscordRecap? recap,
    int? recapWeekday,
    int? recapHour,
    int? Function()? reminderMinutes,
  }) => DiscordChannel(
    groupId: groupId,
    channelName: channelName,
    timezone: timezone,
    recap: recap ?? this.recap,
    recapWeekday: recapWeekday ?? this.recapWeekday,
    recapHour: recapHour ?? this.recapHour,
    reminderMinutes: reminderMinutes != null
        ? reminderMinutes()
        : this.reminderMinutes,
  );
}

abstract interface class DiscordRepository {
  /// Le compte Discord relié à la session, ou `null`.
  Future<DiscordAccount?> fetchAccount();

  /// Émet quand les identités de la session ont pu changer (retour d'une
  /// liaison OAuth, session rafraîchie).
  Stream<void> identityChanges();

  /// Ouvre la liaison OAuth avec Discord (navigateur) ; `false` si la page
  /// n'a pas pu s'ouvrir. Le retour se lit ensuite dans la session.
  Future<bool> linkAccount();

  Future<void> unlinkAccount();

  /// Le salon relié au groupe, ou `null`.
  Future<DiscordChannel?> fetchChannel(String groupId);

  /// Un code à usage unique, valable dix minutes (admins seulement).
  Future<String> createLinkCode(String groupId);

  /// Enregistre les réglages du récap et des rappels (admins seulement).
  Future<void> saveChannel(DiscordChannel channel);

  /// Délie le salon (admins seulement).
  Future<void> unlinkChannel(String groupId);
}
