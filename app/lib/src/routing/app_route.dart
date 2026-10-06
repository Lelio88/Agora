/// Noms des routes d'Agora. Séparés du routeur pour que les écrans naviguent
/// (`context.goNamed(AppRoute.home.name)`) sans importer le routeur, qui
/// les importe tous.
library;

enum AppRoute {
  home,
  group,
  contact,
  groupEvent,
  groupEventNew,
  groupSlots,
  join,
  joinByCode,
  twin,
  assistant,
  consent,
  signIn,
  signUp,
  verifyEmail,
  forgotPassword,
  resetPassword,
}
