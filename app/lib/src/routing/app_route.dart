/// Noms des routes d'Agora. Séparés du routeur pour que les écrans naviguent
/// (`context.goNamed(AppRoute.profile.name)`) sans importer le routeur, qui
/// les importe tous.
library;

enum AppRoute {
  home,
  group,
  groupEvent,
  groupEventNew,
  groupSlots,
  join,
  joinByCode,
  profile,
  signIn,
  signUp,
  verifyEmail,
  forgotPassword,
  resetPassword,
}
