/// Les fournisseurs par lesquels on peut se connecter à Agora, en plus de
/// l'e-mail : la page du fournisseur s'ouvre, puis ramène dans l'app avec
/// une session. Un compte qui n'existait pas est créé à ce moment-là ; une
/// adresse déjà connue d'Agora retrouve son compte.
library;

enum SocialProvider {
  google('google'),
  discord('discord');

  const SocialProvider(this.code);

  /// Nom du fournisseur chez GoTrue, et dans la configuration du build.
  final String code;

  static SocialProvider? fromCode(String code) =>
      values.where((p) => p.code == code.trim()).firstOrNull;
}
