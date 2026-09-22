// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Agora';

  @override
  String get homeTagline => 'Vos agendas, ensemble.';

  @override
  String homeGreeting(String name) {
    return 'Bonjour, $name !';
  }

  @override
  String get profileTooltip => 'Profil';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordHelper =>
      '8 caractères minimum, avec des lettres et des chiffres.';

  @override
  String get displayNameLabel => 'Nom affiché';

  @override
  String get displayNameHelper => 'Visible par les membres de tes groupes.';

  @override
  String get codeLabel => 'Code à 6 chiffres';

  @override
  String get signInTitle => 'Connexion';

  @override
  String get signInButton => 'Se connecter';

  @override
  String get forgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get noAccountPrompt => 'Pas encore de compte ?';

  @override
  String get createAccountLink => 'Créer un compte';

  @override
  String get confirmEmailAction => 'Recevoir un code de confirmation';

  @override
  String get signUpTitle => 'Créer un compte';

  @override
  String get signUpButton => 'Créer mon compte';

  @override
  String get haveAccountPrompt => 'Déjà un compte ?';

  @override
  String get signInLink => 'Se connecter';

  @override
  String get verifyEmailTitle => 'Vérifie ton adresse';

  @override
  String verifyEmailInstructions(String email) {
    return 'Nous avons envoyé un code à 6 chiffres à $email.';
  }

  @override
  String get verifyButton => 'Valider';

  @override
  String get resendCodeButton => 'Renvoyer le code';

  @override
  String get codeResent => 'Nouveau code envoyé.';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotPasswordInstructions =>
      'Indique ton adresse : si un compte y est associé, tu recevras un code pour choisir un nouveau mot de passe.';

  @override
  String get sendCodeButton => 'Recevoir un code';

  @override
  String get resetPasswordTitle => 'Nouveau mot de passe';

  @override
  String resetPasswordInstructions(String email) {
    return 'Saisis le code reçu à $email et choisis un nouveau mot de passe.';
  }

  @override
  String get newPasswordLabel => 'Nouveau mot de passe';

  @override
  String get resetPasswordButton => 'Changer le mot de passe';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileLanguageLabel => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get profileTimezoneLabel => 'Fuseau horaire';

  @override
  String get useDeviceTimezone => 'Utiliser celui de cet appareil';

  @override
  String get saveButton => 'Enregistrer';

  @override
  String get profileSaved => 'Profil enregistré.';

  @override
  String get signOutButton => 'Se déconnecter';

  @override
  String get validationEmail => 'Adresse e-mail invalide.';

  @override
  String get validationPasswordTooShort => '8 caractères minimum.';

  @override
  String get validationPasswordLettersDigits =>
      'Il faut des lettres et des chiffres.';

  @override
  String get validationCode => 'Le code fait 6 chiffres.';

  @override
  String get validationDisplayName => 'Entre 1 et 60 caractères.';

  @override
  String get errorInvalidCredentials => 'Adresse ou mot de passe incorrect.';

  @override
  String get errorEmailNotConfirmed =>
      'Confirme d\'abord ton adresse avec le code reçu par e-mail.';

  @override
  String get errorEmailAlreadyRegistered =>
      'Un compte existe déjà avec cette adresse. Connecte-toi, ou passe par « Mot de passe oublié ».';

  @override
  String get errorInvalidCode => 'Code incorrect ou expiré.';

  @override
  String get errorWeakPassword =>
      'Mot de passe trop faible : 8 caractères minimum, avec des lettres et des chiffres.';

  @override
  String get errorInvalidEmail => 'Adresse e-mail invalide.';

  @override
  String get errorRateLimited =>
      'Trop de tentatives. Réessaie dans quelques minutes.';

  @override
  String get errorInvalidTimezone => 'Fuseau horaire inconnu.';

  @override
  String get errorNetwork =>
      'Impossible de joindre le serveur. Vérifie ta connexion.';

  @override
  String get errorUnknown => 'Une erreur est survenue. Réessaie.';

  @override
  String get deleteAccountButton => 'Supprimer mon compte';

  @override
  String get deleteAccountTitle => 'Supprimer ton compte ?';

  @override
  String get deleteAccountBody =>
      'Ton profil, tes agendas et tes rendez-vous seront effacés définitivement. Les groupes dont tu es propriétaire passent à un autre membre ; ceux où tu es seul·e sont supprimés. Cette action est irréversible.';

  @override
  String get deleteAccountConfirm => 'Supprimer définitivement';

  @override
  String get cancelButton => 'Annuler';

  @override
  String get accountDeleted => 'Ton compte a été supprimé.';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get viewDay => 'Jour';

  @override
  String get viewWeek => 'Semaine';

  @override
  String get viewMonth => 'Mois';

  @override
  String get viewSchedule => 'Planning';

  @override
  String get todayButton => 'Aujourd\'hui';

  @override
  String get previousPeriod => 'Période précédente';

  @override
  String get nextPeriod => 'Période suivante';

  @override
  String get newEventTooltip => 'Nouveau rendez-vous';

  @override
  String get newEventTitle => 'Nouveau rendez-vous';

  @override
  String get editEventTitle => 'Modifier le rendez-vous';

  @override
  String get eventTitleLabel => 'Titre';

  @override
  String get eventLocationLabel => 'Lieu';

  @override
  String get eventDescriptionLabel => 'Notes';

  @override
  String get allDayLabel => 'Journée entière';

  @override
  String get startsLabel => 'Début';

  @override
  String get endsLabel => 'Fin';

  @override
  String get repeatLabel => 'Répétition';

  @override
  String get repeatNever => 'Jamais';

  @override
  String get repeatDaily => 'Tous les jours';

  @override
  String get repeatWeekly => 'Toutes les semaines';

  @override
  String get repeatMonthly => 'Tous les mois';

  @override
  String get repeatYearly => 'Tous les ans';

  @override
  String get repeatAdvanced => 'Règle avancée (importée)';

  @override
  String get visibilityLabel => 'Pour les membres de mes groupes';

  @override
  String get visibilityInherit => 'Selon le groupe';

  @override
  String get visibilityBusy => 'Occupé, sans détail';

  @override
  String get visibilityInvisible => 'Invisible';

  @override
  String get deleteEventButton => 'Supprimer';

  @override
  String get validationTitle => 'Entre 1 et 200 caractères.';

  @override
  String get validationEndBeforeStart => 'La fin doit être après le début.';

  @override
  String get eventSaved => 'Rendez-vous enregistré.';

  @override
  String get eventDeleted => 'Rendez-vous supprimé.';

  @override
  String get scopeTitle => 'Rendez-vous répété';

  @override
  String get scopeEditBody =>
      'Modifier seulement cette occurrence, ou toute la série ?';

  @override
  String get scopeDeleteBody =>
      'Supprimer seulement cette occurrence, ou toute la série ?';

  @override
  String get scopeThisOccurrence => 'Cette occurrence';

  @override
  String get scopeWholeSeries => 'Toute la série';

  @override
  String get noEventsInRange => 'Aucun rendez-vous sur cette période.';

  @override
  String get errorEventNotFound => 'Ce rendez-vous n\'existe plus.';

  @override
  String get errorLastCalendar =>
      'Gardez au moins un agenda : c\'est là que se rangent vos nouveaux rendez-vous.';

  @override
  String get errorCalendarNotFound => 'Cet agenda n\'existe plus.';

  @override
  String get calendarsTitle => 'Mes agendas';

  @override
  String get manageCalendarsTooltip => 'Mes agendas';

  @override
  String get newCalendarButton => 'Nouvel agenda';

  @override
  String get newCalendarTitle => 'Nouvel agenda';

  @override
  String get editCalendarTitle => 'Modifier l\'agenda';

  @override
  String get calendarNameLabel => 'Nom';

  @override
  String get calendarColorLabel => 'Couleur';

  @override
  String get calendarShownTooltip => 'Afficher dans mon agenda';

  @override
  String calendarVisibilitySummary(String level) {
    return 'Groupes : $level';
  }

  @override
  String get validationCalendarName => 'Entre 1 et 60 caractères.';

  @override
  String get calendarSaved => 'Agenda enregistré.';

  @override
  String get deleteCalendarButton => 'Supprimer l\'agenda';

  @override
  String deleteCalendarTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String deleteCalendarBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ses $count rendez-vous seront supprimés avec lui, définitivement.',
      one: 'Son rendez-vous sera supprimé avec lui, définitivement.',
      zero: 'Il ne contient aucun rendez-vous.',
    );
    return '$_temp0';
  }

  @override
  String get calendarDeleted => 'Agenda supprimé.';

  @override
  String get lastCalendarHint => 'Votre seul agenda ne peut pas être supprimé.';

  @override
  String get eventCalendarLabel => 'Agenda';

  @override
  String get scopeMoveBody =>
      'Déplacer seulement cette occurrence, ou toute la série ?';

  @override
  String get scopeCalendarMoveNote =>
      'Changer d\'agenda s\'applique toujours à toute la série.';

  @override
  String get eventMoved => 'Rendez-vous déplacé.';
}
