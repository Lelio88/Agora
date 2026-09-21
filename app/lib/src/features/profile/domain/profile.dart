/// Profil d'un membre : ce que les autres voient (nom) et ses réglages
/// personnels (langue de l'app et des e-mails, fuseau horaire).
library;

enum AppLanguage {
  fr,
  en;

  /// Langue d'un code ISO, français par défaut.
  static AppLanguage fromCode(String? code) => values.firstWhere(
    (language) => language.name == code,
    orElse: () => AppLanguage.fr,
  );
}

final class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.timezone,
    required this.language,
  });

  final String id;
  final String displayName;

  /// Identifiant IANA (ex. `Europe/Paris`), validé par le serveur.
  final String timezone;
  final AppLanguage language;

  Profile copyWith({
    String? displayName,
    String? timezone,
    AppLanguage? language,
  }) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    timezone: timezone ?? this.timezone,
    language: language ?? this.language,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.timezone == timezone &&
      other.language == language;

  @override
  int get hashCode => Object.hash(id, displayName, timezone, language);
}
