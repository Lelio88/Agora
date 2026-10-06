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
    return 'Saisissez le code à 6 chiffres envoyé à $email.';
  }

  @override
  String get verifyEmailExistingAccountHint =>
      'Cette adresse a déjà un compte ? Aucun code n’arrivera : connectez-vous, ou passez par « Mot de passe oublié ».';

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
  String get errorCaptchaFailed =>
      'La vérification a échoué. Réessaie dans un instant.';

  @override
  String get deleteAccountLeftBehind =>
      'Ces rdv que tu as proposés resteront à leurs groupes, sans auteur, mais avec leur texte :';

  @override
  String deleteAccountLeftBehindItem(String title, String group) {
    return '$title — $group';
  }

  @override
  String deleteAccountLeftBehindMore(int count) {
    return 'et $count autres';
  }

  @override
  String get deleteAccountAlsoEvents => 'Supprimer aussi ces rdv';

  @override
  String get legalSectionTitle => 'Informations légales';

  @override
  String get legalPrivacy => 'Politique de confidentialité';

  @override
  String get legalNotice => 'Mentions légales';

  @override
  String get legalTerms => 'Conditions d\'utilisation';

  @override
  String get legalLinkFailed => 'Impossible d\'ouvrir cette page.';

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
  String agendaPeriodSameMonth(
    String first,
    String last,
    String month,
    String year,
  ) {
    return '$first – $last $month $year';
  }

  @override
  String agendaPeriodSameYear(String first, String last, String year) {
    return '$first – $last $year';
  }

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

  @override
  String get errorInvalidInvite =>
      'Ce code d\'invitation n\'est pas valable : inconnu, expiré ou déjà utilisé.';

  @override
  String get errorNotGroupMember => 'Vous ne faites pas partie de ce groupe.';

  @override
  String get errorNotGroupOwner =>
      'Seul le propriétaire du groupe peut faire cela.';

  @override
  String get errorInvalidMember =>
      'Cette personne ne fait pas partie du groupe.';

  @override
  String get navAgenda => 'Agenda';

  @override
  String get navGroups => 'Groupes';

  @override
  String get groupsTitle => 'Groupes';

  @override
  String get noGroups =>
      'Aucun groupe pour l\'instant. Créez-en un, ou rejoignez celui d\'un proche avec son code.';

  @override
  String get newGroupButton => 'Nouveau groupe';

  @override
  String get joinWithCodeButton => 'Rejoindre avec un code';

  @override
  String get groupRoleOwner => 'Propriétaire';

  @override
  String get groupRoleAdmin => 'Admin';

  @override
  String get groupRoleMember => 'Membre';

  @override
  String groupMyShare(String level) {
    return 'Vous partagez : $level';
  }

  @override
  String get newGroupTitle => 'Nouveau groupe';

  @override
  String get groupNameLabel => 'Nom du groupe';

  @override
  String get groupDescriptionLabel => 'Description (facultative)';

  @override
  String get validationGroupName => 'Entre 1 et 60 caractères.';

  @override
  String get createButton => 'Créer';

  @override
  String get groupCreated => 'Groupe créé.';

  @override
  String get joinTitle => 'Rejoindre un groupe';

  @override
  String get inviteCodeLabel => 'Code d\'invitation';

  @override
  String get continueButton => 'Continuer';

  @override
  String joinGroupQuestion(String name) {
    return 'Rejoindre « $name » ?';
  }

  @override
  String joinMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get joinShareQuestion =>
      'Que verront les autres membres de votre agenda ?';

  @override
  String get shareDetails => 'Tout : titres et lieux';

  @override
  String get shareBusy => 'Occupé, sans détail';

  @override
  String get shareNothing => 'Rien';

  @override
  String get shareHint =>
      'Vous pourrez changer ce choix à tout moment dans le groupe. Vos agendas et rendez-vous masqués restent masqués.';

  @override
  String get joinButton => 'Rejoindre';

  @override
  String get alreadyMember => 'Vous faites déjà partie de ce groupe.';

  @override
  String get openGroupButton => 'Ouvrir le groupe';

  @override
  String joinedGroup(String name) {
    return 'Bienvenue dans « $name » !';
  }

  @override
  String get groupMembersTooltip => 'Membres';

  @override
  String get inviteTooltip => 'Inviter';

  @override
  String get memberYou => 'Vous';

  @override
  String get busyLabel => 'Occupé';

  @override
  String get groupEventOwner => 'Groupe';

  @override
  String get renameGroup => 'Renommer le groupe';

  @override
  String get groupSaved => 'Groupe enregistré.';

  @override
  String get leaveGroup => 'Quitter le groupe';

  @override
  String leaveGroupTitle(String name) {
    return 'Quitter « $name » ?';
  }

  @override
  String get leaveGroupBody =>
      'Vous ne verrez plus l\'agenda du groupe, et le groupe ne verra plus le vôtre.';

  @override
  String get leftGroup => 'Vous avez quitté le groupe.';

  @override
  String get ownerMustTransfer =>
      'Transmettez d\'abord le groupe à un autre membre pour pouvoir le quitter.';

  @override
  String get deleteGroup => 'Supprimer le groupe';

  @override
  String deleteGroupTitle(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get deleteGroupBody =>
      'Le groupe disparaît pour tous ses membres. Leurs agendas personnels ne sont pas touchés.';

  @override
  String get groupDeleted => 'Groupe supprimé.';

  @override
  String get membersTitle => 'Membres';

  @override
  String get myShareLabel => 'Ce que je partage avec ce groupe';

  @override
  String memberShares(String level) {
    return 'Partage : $level';
  }

  @override
  String get makeAdmin => 'Nommer admin';

  @override
  String get removeAdmin => 'Retirer le rôle d\'admin';

  @override
  String get transferGroup => 'Transmettre le groupe';

  @override
  String transferTitle(String name) {
    return 'Transmettre le groupe à $name ?';
  }

  @override
  String transferBody(String name) {
    return '$name en deviendra propriétaire ; vous resterez admin.';
  }

  @override
  String get removeMember => 'Exclure du groupe';

  @override
  String removeMemberTitle(String name) {
    return 'Exclure $name ?';
  }

  @override
  String get memberRemoved => 'Membre exclu.';

  @override
  String get roleChanged => 'Rôle mis à jour.';

  @override
  String get groupTransferred => 'Groupe transmis.';

  @override
  String get shareSaved => 'Partage enregistré.';

  @override
  String inviteTitle(String name) {
    return 'Inviter dans « $name »';
  }

  @override
  String inviteCodeHint(String date) {
    return 'Toute personne qui a ce code peut rejoindre le groupe jusqu\'au $date.';
  }

  @override
  String get copyCode => 'Copier le code';

  @override
  String get copyLink => 'Copier le lien';

  @override
  String get codeCopied => 'Code copié.';

  @override
  String get linkCopied => 'Lien copié.';

  @override
  String get revokeInvite => 'Désactiver ce code';

  @override
  String get inviteRevoked => 'Code désactivé.';

  @override
  String get errorInvalidFeedUrl =>
      'Ce lien n\'est pas un lien d\'agenda valable : il doit commencer par https:// ou webcal://.';

  @override
  String get errorTooManyFeeds =>
      'Vous avez déjà importé 10 agendas : supprimez-en un pour en ajouter un autre.';

  @override
  String get importCalendarTitle => 'Importer un agenda';

  @override
  String get importCalendarHint => 'Google, Outlook, Apple… par son lien iCal';

  @override
  String get importCalendarButton => 'Importer';

  @override
  String get importUrlLabel => 'Lien iCal de l\'agenda';

  @override
  String get importUrlPrivacy =>
      'Ce lien ouvre tout votre agenda : il reste sur le serveur d\'Agora, qui ne le montre à personne, pas même à vos groupes.';

  @override
  String get validationFeedUrl =>
      'Collez un lien qui commence par https:// ou webcal://, sans espace.';

  @override
  String get importHelpTitle => 'Où trouver ce lien ?';

  @override
  String get importHelpGoogle =>
      'Sur ordinateur : Paramètres → votre agenda → Intégrer l\'agenda → « Adresse secrète au format iCal ».';

  @override
  String get importHelpOutlook =>
      'Paramètres → Calendrier → Calendriers partagés → Publier un calendrier → choisissez l\'agenda, puis copiez le lien ICS.';

  @override
  String get importHelpApple =>
      'App Calendrier → partager l\'agenda → cochez « Calendrier public » → copiez le lien webcal://.';

  @override
  String get importHelpRefresh =>
      'Agora relit l\'agenda toutes les 30 minutes. Ses rendez-vous sont en lecture seule : on les modifie dans l\'agenda d\'origine.';

  @override
  String get calendarImported =>
      'Agenda importé : ses rendez-vous arrivent dans un instant.';

  @override
  String get importedCalendarLabel => 'Importé par lien iCal';

  @override
  String get syncNowButton => 'Synchroniser maintenant';

  @override
  String get syncRequested => 'Synchronisation demandée.';

  @override
  String get syncPending => 'Première synchronisation en cours…';

  @override
  String syncedAt(String when) {
    return 'Synchronisé le $when';
  }

  @override
  String get syncErrorUnreachable =>
      'Lien injoignable pour l\'instant ; nouvel essai bientôt.';

  @override
  String get syncErrorTimeout =>
      'Le serveur de l\'agenda ne répond pas ; nouvel essai bientôt.';

  @override
  String get syncErrorNotFound =>
      'Lien introuvable : l\'agenda a été supprimé ou son lien a changé.';

  @override
  String get syncErrorForbidden =>
      'Accès refusé : ce lien n\'est plus valable.';

  @override
  String get syncErrorHttp =>
      'Le serveur de l\'agenda a répondu par une erreur ; nouvel essai bientôt.';

  @override
  String get syncErrorTooLarge => 'Agenda trop volumineux (plus de 5 Mo).';

  @override
  String get syncErrorNotCalendar => 'Ce lien ne mène pas à un agenda iCal.';

  @override
  String get syncErrorBlockedAddress =>
      'Ce lien mène à une adresse privée, refusée par Agora.';

  @override
  String get syncErrorTooManyEvents =>
      'Agenda trop chargé : plus de 5 000 rendez-vous à importer.';

  @override
  String get syncErrorUnknown => 'La dernière synchronisation a échoué.';

  @override
  String get importedEventReadOnly =>
      'Rendez-vous importé : modifiez-le dans l\'agenda d\'origine. Vous choisissez ici ce qu\'en voient vos groupes.';

  @override
  String get importedEventSeriesNote => 'S\'applique à toute la série.';

  @override
  String get eventVisibilitySaved => 'Réglage enregistré.';

  @override
  String get proposeEventButton => 'Proposer un rdv';

  @override
  String get eventProposed => 'Rendez-vous proposé au groupe.';

  @override
  String get myResponseLabel => 'Ma réponse';

  @override
  String get responseYes => 'Présent';

  @override
  String get responseMaybe => 'Peut-être';

  @override
  String get responseNo => 'Absent';

  @override
  String get responseNone => 'Sans réponse';

  @override
  String get responsesTitle => 'Réponses';

  @override
  String responseSectionTitle(String label, int count) {
    return '$label · $count';
  }

  @override
  String proposedBy(String name) {
    return 'Proposé par $name';
  }

  @override
  String get responseSaved => 'Réponse enregistrée.';

  @override
  String get responseRemoved => 'Réponse retirée.';

  @override
  String get occurrenceResponseNote =>
      'Rendez-vous répété : votre réponse vaut pour cette date.';

  @override
  String get groupCalendarsTitle => 'Agendas de mes groupes';

  @override
  String get proposedByMe => 'Proposé par vous';

  @override
  String get findSlotTooltip => 'Trouver un créneau';

  @override
  String get findSlotTitle => 'Créneaux communs';

  @override
  String get slotDurationLabel => 'Durée';

  @override
  String get slotPeriodLabel => 'Période';

  @override
  String slotPeriodDays(int count) {
    return '$count prochains jours';
  }

  @override
  String get slotNotBeforeLabel => 'Pas avant';

  @override
  String get slotNotAfterLabel => 'Pas après';

  @override
  String get slotWeekendsLabel => 'Week-ends compris';

  @override
  String get slotAllDayLabel => 'Les journées entières comptent comme prises';

  @override
  String get slotMembersLabel => 'Qui doit être là';

  @override
  String slotInvisibleNote(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$names ne partagent pas leur agenda avec le groupe : ces personnes paraissent toujours libres.',
      one:
          '$names ne partage pas son agenda avec le groupe : cette personne paraît toujours libre.',
    );
    return '$_temp0';
  }

  @override
  String get slotsHint =>
      'Seul ce que chacun partage avec le groupe compte ; un rdv du groupe prend le créneau.';

  @override
  String get slotsNone =>
      'Aucun créneau libre pour tout le monde sur cette période.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes';
  }

  @override
  String get slotMoreCriteria => 'Heures, jours et membres';

  @override
  String get errorNotGroupAdmin => 'Seul un admin du groupe peut faire cela.';

  @override
  String get errorDiscordAlreadyLinked =>
      'Ce compte Discord est déjà relié à un autre compte Agora.';

  @override
  String get discordSectionTitle => 'Discord';

  @override
  String discordAccountLinked(String name) {
    return 'Relié à $name';
  }

  @override
  String get discordAccountNotLinked =>
      'Relie ton compte Discord pour utiliser /agenda et /dispo avec le bot Agora.';

  @override
  String get discordLinkButton => 'Relier Discord';

  @override
  String get discordUnlinkButton => 'Délier';

  @override
  String get discordLinkFailed => 'Impossible d\'ouvrir Discord.';

  @override
  String get groupDiscordMenu => 'Salon Discord';

  @override
  String get discordChannelTitle => 'Salon Discord';

  @override
  String get discordChannelNone =>
      'Aucun salon Discord n\'est relié à ce groupe.';

  @override
  String get discordChannelAskAdmin => 'Un admin du groupe peut en relier un.';

  @override
  String discordChannelLinked(String name) {
    return 'Relié à #$name';
  }

  @override
  String get discordChannelLinkedUnnamed => 'Relié à un salon Discord';

  @override
  String get discordLinkSteps =>
      'Invite le bot sur ton serveur, puis crée un code et tape la commande dans le salon voulu. Il faut pouvoir gérer ce salon.';

  @override
  String get discordInviteBot => 'Inviter le bot sur un serveur';

  @override
  String get discordCreateCode => 'Créer un code de liaison';

  @override
  String get discordCodeInstructions =>
      'Dans les 10 minutes, tape dans le salon à relier :';

  @override
  String discordLinkCommand(String code) {
    return '/relier $code';
  }

  @override
  String get discordCopyCommand => 'Copier';

  @override
  String get discordCommandCopied => 'Commande copiée.';

  @override
  String get discordCheckLink => 'J\'ai tapé la commande';

  @override
  String get discordRecapLabel => 'Récap dans le salon';

  @override
  String get discordRecapOff => 'Aucun';

  @override
  String get discordRecapDaily => 'Chaque jour';

  @override
  String get discordRecapWeekly => 'Chaque semaine';

  @override
  String get discordRecapDay => 'Jour';

  @override
  String get discordRecapHour => 'Heure';

  @override
  String discordRecapHourValue(int hour) {
    return '$hour h';
  }

  @override
  String discordRecapTimezone(String timezone) {
    return 'Heures de $timezone';
  }

  @override
  String get discordReminderLabel => 'Rappel avant les rdv du groupe';

  @override
  String get discordReminderOff => 'Aucun';

  @override
  String get discordReminder15 => '15 min avant';

  @override
  String get discordReminder60 => '1 h avant';

  @override
  String get discordReminder1440 => 'La veille';

  @override
  String get discordPublicNotice =>
      'Tout le salon voit les récaps et les rappels, même des personnes hors du groupe : les rdv du groupe y figurent en détail, les rdv personnels seulement comme « occupé ».';

  @override
  String get discordSaved => 'Réglages enregistrés.';

  @override
  String get discordUnlinkChannel => 'Délier le salon';

  @override
  String get goThereButton => 'Y aller';

  @override
  String get goThereTitle => 'Y aller en transports';

  @override
  String goThereArriveBy(String when) {
    return 'Pour arriver le $when';
  }

  @override
  String get goThereOriginLabel => 'Partir d\'une autre adresse';

  @override
  String get goThereOriginHelper =>
      'Sinon, depuis ta position. Rien n\'est enregistré.';

  @override
  String get goThereCitymapper => 'Citymapper';

  @override
  String get goThereGoogleMaps => 'Google Maps';

  @override
  String get goThereGoogleNote =>
      'Dans Google Maps, règle l\'heure d\'arrivée toi-même : le lien ne peut pas la transmettre.';

  @override
  String get goThereOtherApp => 'Autre app de cartes';

  @override
  String get goThereFailed => 'Aucune app n\'a pu ouvrir l\'itinéraire.';

  @override
  String get orDivider => 'ou';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get continueWithDiscord => 'Continuer avec Discord';

  @override
  String get socialSignInFailed => 'Impossible d\'ouvrir la page de connexion.';

  @override
  String get errorConsentExpired =>
      'Cette demande d\'accès a expiré ou a déjà été traitée. Relance la connexion depuis ton assistant.';

  @override
  String get errorAssistantsUnavailable =>
      'Le branchement des assistants IA n\'est pas encore ouvert.';

  @override
  String get assistantTitle => 'Assistant IA';

  @override
  String get assistantProfileSubtitle =>
      'Brancher Claude, ChatGPT… sur ton agenda';

  @override
  String get assistantIntro =>
      'Un assistant IA branché sur Agora lit ton agenda et ceux de tes groupes comme l\'app te les montre, cherche des créneaux communs, crée tes rdv, en propose à un groupe et y répond — toujours à ton nom. Il ne modifie ni ne supprime rien.';

  @override
  String get assistantAddressTitle => 'Adresse du connecteur';

  @override
  String get assistantCopy => 'Copier';

  @override
  String get assistantCopied => 'Copié.';

  @override
  String get assistantClaudeAi =>
      'Dans claude.ai : Paramètres → Connecteurs → Ajouter un connecteur personnalisé, puis colle l\'adresse.';

  @override
  String get assistantClaudeCode =>
      'Dans Claude Code, puis /mcp → Authenticate :';

  @override
  String get assistantOthers =>
      'ChatGPT, Cursor, VS Code : la même adresse, dans leurs réglages de connecteurs MCP.';

  @override
  String get assistantGuide => 'Mode d\'emploi détaillé';

  @override
  String get assistantNoAddress =>
      'Cette version de l\'app ne connaît pas l\'adresse du serveur.';

  @override
  String get assistantGrantsTitle => 'Assistants autorisés';

  @override
  String get assistantRevokeImmediate => 'Retirer un accès le coupe aussitôt.';

  @override
  String get assistantNoGrant => 'Aucun assistant n\'a accès à ton agenda.';

  @override
  String assistantGrantedOn(String date) {
    return 'Autorisé le $date';
  }

  @override
  String get assistantRevoke => 'Retirer';

  @override
  String get assistantRevokeTitle => 'Retirer l\'accès ?';

  @override
  String assistantRevokeBody(String name) {
    return '$name ne pourra plus lire ton agenda ni agir pour toi. Tu pourras l\'autoriser de nouveau depuis l\'assistant.';
  }

  @override
  String get assistantRevoked => 'Accès retiré.';

  @override
  String get assistantUnnamed => 'Assistant sans nom';

  @override
  String get assistantLocalTool =>
      'un outil de cet ordinateur (Claude Code, Cursor, VS Code…)';

  @override
  String get consentTitle => 'Autoriser un assistant';

  @override
  String consentQuestion(String assistant) {
    return 'Autoriser $assistant à accéder à ton agenda Agora ?';
  }

  @override
  String consentPresentsAs(String name) {
    return 'Il se présente comme « $name ».';
  }

  @override
  String get consentCanTitle => 'Il pourra :';

  @override
  String get consentCanRead =>
      'lire ton agenda et celui de tes groupes, comme l\'app te les montre ;';

  @override
  String get consentCanSlots => 'chercher des créneaux communs ;';

  @override
  String get consentCanWrite =>
      'créer un rdv dans ton agenda, proposer un rdv à un de tes groupes, répondre à un rdv de groupe.';

  @override
  String get consentCannotTitle => 'Il ne pourra pas :';

  @override
  String get consentCannot =>
      'modifier ni supprimer un rdv, ni toucher à tes groupes, à ton partage ou à ton compte.';

  @override
  String get consentWarning =>
      'N\'autorise qu\'un assistant que tu utilises toi-même. Tu pourras retirer l\'accès à tout moment : Profil → Assistant IA.';

  @override
  String consentAccount(String email) {
    return 'Compte : $email';
  }

  @override
  String get consentNotMe => 'Ce n\'est pas moi';

  @override
  String get consentApprove => 'Autoriser';

  @override
  String get consentDeny => 'Refuser';

  @override
  String get consentHandedOver => 'Retour vers l\'assistant…';

  @override
  String get consentHandOverFailed =>
      'Le retour vers l\'assistant n\'a pas pu s\'ouvrir. Relance la connexion depuis l\'assistant.';

  @override
  String get consentDenied => 'Accès refusé.';

  @override
  String consentUnknownAssistant(String host) {
    return 'Accès refusé : cette demande ne vient pas d\'un assistant reconnu ($host).';
  }

  @override
  String get consentHome => 'Retour à l\'accueil';

  @override
  String get shareDetailsAssistantHint =>
      'Avec « Tout », les membres voient titres et lieux, y compris par l\'assistant IA qu\'ils ont branché sur Agora.';

  @override
  String get errorInvalidTwinLink => 'Ce lien de jumelage n\'est pas valable.';

  @override
  String get twinMenu => 'Jumelage';

  @override
  String get twinTitle => 'Jumelage';

  @override
  String twinAlsoIn(String app) {
    return 'Ce groupe existe aussi dans $app.';
  }

  @override
  String get twinJoinButton => 'Rejoindre';

  @override
  String twinExplain(String app) {
    return 'Un jumeau est un groupe d\'une autre app. Ses membres y voient « Rejoindre aussi dans Agora », et ceux d\'ici « Rejoindre aussi dans $app ». Chacun rejoint lui-même : personne n\'est ajouté d\'office.';
  }

  @override
  String twinStartButton(String app) {
    return 'Jumeler avec $app';
  }

  @override
  String twinPending(String app) {
    return 'En attente de la réponse de $app. Si elle ne vient pas, relance le jumelage.';
  }

  @override
  String get twinRestartButton => 'Relancer';

  @override
  String twinLinked(String app) {
    return 'Jumelé avec un groupe $app.';
  }

  @override
  String get twinUnlinkButton => 'Défaire le jumelage';

  @override
  String twinUnlinkTitle(String app) {
    return 'Défaire le jumelage avec $app ?';
  }

  @override
  String twinUnlinkBody(String app) {
    return 'Le code donné à $app n\'ouvrira plus ce groupe. Dans $app, le bouton restera affiché jusqu\'à ce qu\'on l\'y retire.';
  }

  @override
  String get twinUnlinked => 'Jumelage défait.';

  @override
  String twinRequestTitle(String app, String name) {
    return 'Le groupe $app « $name » propose un jumelage.';
  }

  @override
  String twinRequestTitleUnnamed(String app) {
    return 'Un groupe $app propose un jumelage.';
  }

  @override
  String get twinChooseGroup => 'Avec quel groupe Agora ?';

  @override
  String get twinNewGroup => 'Un nouveau groupe';

  @override
  String get twinConfirmButton => 'Jumeler';

  @override
  String twinResponseQuestion(String group, String app) {
    return 'Relier « $group » au groupe $app choisi ?';
  }

  @override
  String get twinLinkButton => 'Relier';

  @override
  String get twinResponseUnknown =>
      'Cette réponse ne correspond à aucun jumelage lancé depuis cet appareil. Relance le jumelage depuis le menu du groupe.';

  @override
  String get twinSaved => 'Jumelage enregistré.';

  @override
  String twinOpenFailed(String app) {
    return 'Impossible d\'ouvrir $app. Le jumelage est enregistré ici ; relance-le depuis le menu du groupe pour finir.';
  }

  @override
  String get errorTwinExists =>
      'Ce groupe est déjà jumelé avec un autre groupe de cette app. Défais d\'abord ce jumelage depuis le menu du groupe.';

  @override
  String get newContactTitle => 'Nouveau proche';

  @override
  String get contactNameLabel => 'Nom du proche';

  @override
  String get contactCalendarHint =>
      'Visible de toi seul : ses repos et son anniversaire ne comptent jamais comme tes créneaux pris.';

  @override
  String get contactCalendarsTitle => 'Proches';

  @override
  String get newContactButton => 'Ajouter un proche';

  @override
  String get newContactHint => 'Ses repos, son anniversaire : pour toi seul';

  @override
  String get contactSaved => 'Proche ajouté.';

  @override
  String get contactCalendarSubtitle => 'Pour toi seul';

  @override
  String get importForContactLabel => 'Le planning d\'un proche';

  @override
  String get importForContactHint =>
      'Visible de toi seul, jamais compté comme tes créneaux pris.';

  @override
  String get navSocial => 'Social';

  @override
  String get navMe => 'Moi';

  @override
  String get socialAddButton => 'Ajouter';

  @override
  String get upcomingTitle => 'À venir';

  @override
  String daysAwayLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dans $count jours',
      one: 'Demain',
      zero: 'Aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get contactsEmpty =>
      'Note les repos et l\'anniversaire de tes proches : tu es seul à les voir.';

  @override
  String get contactImportedSubtitle => 'Planning importé, pour toi seul';

  @override
  String get contactNowTitle => 'En ce moment';

  @override
  String get contactNothingNow => 'Rien de noté en ce moment.';

  @override
  String contactUntil(String title, String time) {
    return '$title, jusqu\'à $time';
  }

  @override
  String contactNext(String title, String when) {
    return 'Ensuite : $title, $when';
  }

  @override
  String get contactShortcutsTitle => 'Ajouter vite';

  @override
  String get shortcutBirthday => 'Anniversaire';

  @override
  String get shortcutWorkHours => 'Horaires de travail';

  @override
  String get shortcutRest => 'Jour de repos';

  @override
  String get shortcutImport => 'Importer son planning';

  @override
  String birthdayEventTitle(String name) {
    return 'Anniversaire de $name';
  }

  @override
  String get workEventTitle => 'Travail';

  @override
  String get restEventTitle => 'Repos';

  @override
  String contactImportedName(String name) {
    return 'Planning de $name';
  }

  @override
  String get contactUpcomingTitle => 'Les 30 prochains jours';

  @override
  String get contactNothingUpcoming =>
      'Rien de noté pour les 30 prochains jours.';

  @override
  String get contactAddEventButton => 'Ajouter';

  @override
  String get contactEditTooltip => 'Modifier le proche';

  @override
  String get repeatDaysLabel => 'Les jours';

  @override
  String get repeatIntervalLabel => 'Rythme';

  @override
  String repeatEveryWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Toutes les $count semaines',
      one: 'Chaque semaine',
    );
    return '$_temp0';
  }

  @override
  String get repeatEndLabel => 'Fin de la répétition';

  @override
  String get repeatEndNever => 'Jamais';

  @override
  String repeatEndOn(String date) {
    return 'Le $date';
  }

  @override
  String get repeatEndClearTooltip => 'Sans fin';
}
