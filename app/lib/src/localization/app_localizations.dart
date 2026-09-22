import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Nom de l'application, identique dans toutes les langues.
  ///
  /// In fr, this message translates to:
  /// **'Agora'**
  String get appTitle;

  /// Accroche de l'écran de connexion et de l'accueil.
  ///
  /// In fr, this message translates to:
  /// **'Vos agendas, ensemble.'**
  String get homeTagline;

  /// Salutation de l'accueil, avec le nom affiché du profil.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, {name} !'**
  String homeGreeting(String name);

  /// Infobulle du bouton qui ouvre le profil.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTooltip;

  /// Champ adresse e-mail des formulaires de compte.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail'**
  String get emailLabel;

  /// Champ mot de passe de la connexion et de l'inscription.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordLabel;

  /// Règle du mot de passe, rappelée sous le champ.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères minimum, avec des lettres et des chiffres.'**
  String get passwordHelper;

  /// Champ du nom visible par les autres membres.
  ///
  /// In fr, this message translates to:
  /// **'Nom affiché'**
  String get displayNameLabel;

  /// Précision sous le champ du nom affiché.
  ///
  /// In fr, this message translates to:
  /// **'Visible par les membres de tes groupes.'**
  String get displayNameHelper;

  /// Champ du code reçu par e-mail.
  ///
  /// In fr, this message translates to:
  /// **'Code à 6 chiffres'**
  String get codeLabel;

  /// Titre de l'écran de connexion.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get signInTitle;

  /// Bouton qui valide la connexion.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signInButton;

  /// Lien vers la réinitialisation du mot de passe.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get forgotPasswordLink;

  /// Question avant le lien d'inscription.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de compte ?'**
  String get noAccountPrompt;

  /// Lien vers l'inscription.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get createAccountLink;

  /// Bouton proposé quand on se connecte avant d'avoir confirmé son adresse.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un code de confirmation'**
  String get confirmEmailAction;

  /// Titre de l'écran d'inscription.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get signUpTitle;

  /// Bouton qui valide l'inscription.
  ///
  /// In fr, this message translates to:
  /// **'Créer mon compte'**
  String get signUpButton;

  /// Question avant le lien de connexion.
  ///
  /// In fr, this message translates to:
  /// **'Déjà un compte ?'**
  String get haveAccountPrompt;

  /// Lien vers la connexion.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get signInLink;

  /// Titre de l'écran de saisie du code de confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Vérifie ton adresse'**
  String get verifyEmailTitle;

  /// Explication sous le titre de la confirmation d'adresse.
  ///
  /// In fr, this message translates to:
  /// **'Nous avons envoyé un code à 6 chiffres à {email}.'**
  String verifyEmailInstructions(String email);

  /// Bouton qui valide le code de confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get verifyButton;

  /// Bouton qui redemande un code.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer le code'**
  String get resendCodeButton;

  /// Confirmation après l'envoi d'un nouveau code.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code envoyé.'**
  String get codeResent;

  /// Titre de l'écran de demande de réinitialisation.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié'**
  String get forgotPasswordTitle;

  /// Explication de la réinitialisation, volontairement neutre sur l'existence du compte.
  ///
  /// In fr, this message translates to:
  /// **'Indique ton adresse : si un compte y est associé, tu recevras un code pour choisir un nouveau mot de passe.'**
  String get forgotPasswordInstructions;

  /// Bouton qui envoie le code de réinitialisation.
  ///
  /// In fr, this message translates to:
  /// **'Recevoir un code'**
  String get sendCodeButton;

  /// Titre de l'écran de choix du nouveau mot de passe.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get resetPasswordTitle;

  /// Explication de l'écran de choix du nouveau mot de passe.
  ///
  /// In fr, this message translates to:
  /// **'Saisis le code reçu à {email} et choisis un nouveau mot de passe.'**
  String resetPasswordInstructions(String email);

  /// Champ du nouveau mot de passe.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau mot de passe'**
  String get newPasswordLabel;

  /// Bouton qui enregistre le nouveau mot de passe.
  ///
  /// In fr, this message translates to:
  /// **'Changer le mot de passe'**
  String get resetPasswordButton;

  /// Titre de l'écran de profil.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// Réglage de la langue de l'app et des e-mails.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get profileLanguageLabel;

  /// Nom de la langue française, écrit dans cette langue.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// Nom de la langue anglaise, écrit dans cette langue.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Réglage du fuseau horaire.
  ///
  /// In fr, this message translates to:
  /// **'Fuseau horaire'**
  String get profileTimezoneLabel;

  /// Bouton qui reprend le fuseau horaire de l'appareil.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser celui de cet appareil'**
  String get useDeviceTimezone;

  /// Bouton d'enregistrement d'un formulaire.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get saveButton;

  /// Confirmation après l'enregistrement du profil.
  ///
  /// In fr, this message translates to:
  /// **'Profil enregistré.'**
  String get profileSaved;

  /// Bouton de déconnexion.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get signOutButton;

  /// Erreur de saisie : adresse mal formée.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide.'**
  String get validationEmail;

  /// Erreur de saisie : mot de passe trop court.
  ///
  /// In fr, this message translates to:
  /// **'8 caractères minimum.'**
  String get validationPasswordTooShort;

  /// Erreur de saisie : il manque des lettres ou des chiffres.
  ///
  /// In fr, this message translates to:
  /// **'Il faut des lettres et des chiffres.'**
  String get validationPasswordLettersDigits;

  /// Erreur de saisie : code mal formé.
  ///
  /// In fr, this message translates to:
  /// **'Le code fait 6 chiffres.'**
  String get validationCode;

  /// Erreur de saisie : nom affiché vide ou trop long.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 60 caractères.'**
  String get validationDisplayName;

  /// Échec de connexion. Ne dit jamais si le compte existe.
  ///
  /// In fr, this message translates to:
  /// **'Adresse ou mot de passe incorrect.'**
  String get errorInvalidCredentials;

  /// Connexion refusée tant que l'adresse n'est pas confirmée.
  ///
  /// In fr, this message translates to:
  /// **'Confirme d\'abord ton adresse avec le code reçu par e-mail.'**
  String get errorEmailNotConfirmed;

  /// Inscription avec une adresse déjà utilisée.
  ///
  /// In fr, this message translates to:
  /// **'Un compte existe déjà avec cette adresse. Connecte-toi, ou passe par « Mot de passe oublié ».'**
  String get errorEmailAlreadyRegistered;

  /// Code de confirmation ou de réinitialisation refusé.
  ///
  /// In fr, this message translates to:
  /// **'Code incorrect ou expiré.'**
  String get errorInvalidCode;

  /// Mot de passe refusé par le serveur.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe trop faible : 8 caractères minimum, avec des lettres et des chiffres.'**
  String get errorWeakPassword;

  /// Adresse refusée par le serveur.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail invalide.'**
  String get errorInvalidEmail;

  /// Limite de fréquence atteinte.
  ///
  /// In fr, this message translates to:
  /// **'Trop de tentatives. Réessaie dans quelques minutes.'**
  String get errorRateLimited;

  /// Fuseau refusé par le serveur.
  ///
  /// In fr, this message translates to:
  /// **'Fuseau horaire inconnu.'**
  String get errorInvalidTimezone;

  /// Serveur injoignable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur. Vérifie ta connexion.'**
  String get errorNetwork;

  /// Erreur sans traduction plus précise.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue. Réessaie.'**
  String get errorUnknown;

  /// Bouton qui ouvre la confirmation de suppression du compte.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer mon compte'**
  String get deleteAccountButton;

  /// Titre de la confirmation de suppression.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ton compte ?'**
  String get deleteAccountTitle;

  /// Conséquences de la suppression, affichées avant confirmation.
  ///
  /// In fr, this message translates to:
  /// **'Ton profil, tes agendas et tes rendez-vous seront effacés définitivement. Les groupes dont tu es propriétaire passent à un autre membre ; ceux où tu es seul·e sont supprimés. Cette action est irréversible.'**
  String get deleteAccountBody;

  /// Bouton qui confirme la suppression du compte.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer définitivement'**
  String get deleteAccountConfirm;

  /// Bouton d'annulation d'une boîte de dialogue.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancelButton;

  /// Confirmation affichée après la suppression du compte.
  ///
  /// In fr, this message translates to:
  /// **'Ton compte a été supprimé.'**
  String get accountDeleted;

  /// Titre de l'écran d'agenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get agendaTitle;

  /// Bouton de la vue jour.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get viewDay;

  /// Bouton de la vue semaine.
  ///
  /// In fr, this message translates to:
  /// **'Semaine'**
  String get viewWeek;

  /// Bouton de la vue mois.
  ///
  /// In fr, this message translates to:
  /// **'Mois'**
  String get viewMonth;

  /// Bouton de la vue planning (liste chronologique).
  ///
  /// In fr, this message translates to:
  /// **'Planning'**
  String get viewSchedule;

  /// Bouton qui ramène l'agenda à la date du jour.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui'**
  String get todayButton;

  /// Infobulle du bouton qui recule d'une page.
  ///
  /// In fr, this message translates to:
  /// **'Période précédente'**
  String get previousPeriod;

  /// Infobulle du bouton qui avance d'une page.
  ///
  /// In fr, this message translates to:
  /// **'Période suivante'**
  String get nextPeriod;

  /// Infobulle du bouton de création.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau rendez-vous'**
  String get newEventTooltip;

  /// Titre de l'éditeur à la création.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau rendez-vous'**
  String get newEventTitle;

  /// Titre de l'éditeur à la modification.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le rendez-vous'**
  String get editEventTitle;

  /// Champ du titre d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Titre'**
  String get eventTitleLabel;

  /// Champ du lieu d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get eventLocationLabel;

  /// Champ de la description d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Notes'**
  String get eventDescriptionLabel;

  /// Interrupteur « journée entière ».
  ///
  /// In fr, this message translates to:
  /// **'Journée entière'**
  String get allDayLabel;

  /// Libellé du début d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Début'**
  String get startsLabel;

  /// Libellé de la fin d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Fin'**
  String get endsLabel;

  /// Libellé du choix de répétition.
  ///
  /// In fr, this message translates to:
  /// **'Répétition'**
  String get repeatLabel;

  /// Répétition : aucune.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get repeatNever;

  /// Répétition quotidienne.
  ///
  /// In fr, this message translates to:
  /// **'Tous les jours'**
  String get repeatDaily;

  /// Répétition hebdomadaire.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les semaines'**
  String get repeatWeekly;

  /// Répétition mensuelle.
  ///
  /// In fr, this message translates to:
  /// **'Tous les mois'**
  String get repeatMonthly;

  /// Répétition annuelle.
  ///
  /// In fr, this message translates to:
  /// **'Tous les ans'**
  String get repeatYearly;

  /// Répétition importée que l'éditeur ne sait pas représenter ; conservée telle quelle.
  ///
  /// In fr, this message translates to:
  /// **'Règle avancée (importée)'**
  String get repeatAdvanced;

  /// Libellé du réglage de visibilité d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Pour les membres de mes groupes'**
  String get visibilityLabel;

  /// Visibilité : hérite du réglage du groupe et de l'agenda.
  ///
  /// In fr, this message translates to:
  /// **'Selon le groupe'**
  String get visibilityInherit;

  /// Visibilité : créneau visible, sans titre ni lieu.
  ///
  /// In fr, this message translates to:
  /// **'Occupé, sans détail'**
  String get visibilityBusy;

  /// Visibilité : le rendez-vous n'existe pas pour les autres.
  ///
  /// In fr, this message translates to:
  /// **'Invisible'**
  String get visibilityInvisible;

  /// Bouton de suppression d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get deleteEventButton;

  /// Erreur de saisie : titre vide ou trop long.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 200 caractères.'**
  String get validationTitle;

  /// Erreur de saisie : fin avant le début.
  ///
  /// In fr, this message translates to:
  /// **'La fin doit être après le début.'**
  String get validationEndBeforeStart;

  /// Confirmation après l'enregistrement d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous enregistré.'**
  String get eventSaved;

  /// Confirmation après la suppression d'un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous supprimé.'**
  String get eventDeleted;

  /// Titre du choix entre une occurrence et toute la série.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous répété'**
  String get scopeTitle;

  /// Question posée avant de modifier un rendez-vous répété.
  ///
  /// In fr, this message translates to:
  /// **'Modifier seulement cette occurrence, ou toute la série ?'**
  String get scopeEditBody;

  /// Question posée avant de supprimer un rendez-vous répété.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer seulement cette occurrence, ou toute la série ?'**
  String get scopeDeleteBody;

  /// Choix : une seule occurrence.
  ///
  /// In fr, this message translates to:
  /// **'Cette occurrence'**
  String get scopeThisOccurrence;

  /// Choix : toute la série.
  ///
  /// In fr, this message translates to:
  /// **'Toute la série'**
  String get scopeWholeSeries;

  /// Texte de la vue planning quand elle est vide.
  ///
  /// In fr, this message translates to:
  /// **'Aucun rendez-vous sur cette période.'**
  String get noEventsInRange;

  /// Le rendez-vous a été supprimé entre-temps.
  ///
  /// In fr, this message translates to:
  /// **'Ce rendez-vous n\'existe plus.'**
  String get errorEventNotFound;

  /// Refus de supprimer le dernier agenda de l'utilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Gardez au moins un agenda : c\'est là que se rangent vos nouveaux rendez-vous.'**
  String get errorLastCalendar;

  /// L'agenda a été supprimé entre-temps, ou n'appartient pas à l'utilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Cet agenda n\'existe plus.'**
  String get errorCalendarNotFound;

  /// Titre de l'écran de gestion des agendas.
  ///
  /// In fr, this message translates to:
  /// **'Mes agendas'**
  String get calendarsTitle;

  /// Infobulle du bouton qui ouvre la gestion des agendas.
  ///
  /// In fr, this message translates to:
  /// **'Mes agendas'**
  String get manageCalendarsTooltip;

  /// Bouton qui crée un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel agenda'**
  String get newCalendarButton;

  /// Titre du formulaire de création d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Nouvel agenda'**
  String get newCalendarTitle;

  /// Titre du formulaire de modification d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l\'agenda'**
  String get editCalendarTitle;

  /// Champ du nom d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get calendarNameLabel;

  /// Libellé du choix de couleur d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Couleur'**
  String get calendarColorLabel;

  /// Case qui montre ou masque un agenda dans sa propre vue (sans effet pour les groupes).
  ///
  /// In fr, this message translates to:
  /// **'Afficher dans mon agenda'**
  String get calendarShownTooltip;

  /// Sous-titre d'un agenda dans la liste : ce que voient les groupes.
  ///
  /// In fr, this message translates to:
  /// **'Groupes : {level}'**
  String calendarVisibilitySummary(String level);

  /// Erreur de saisie : nom d'agenda vide ou trop long.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 60 caractères.'**
  String get validationCalendarName;

  /// Confirmation après l'enregistrement d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda enregistré.'**
  String get calendarSaved;

  /// Bouton de suppression d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'agenda'**
  String get deleteCalendarButton;

  /// Titre de la confirmation de suppression d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String deleteCalendarTitle(String name);

  /// Conséquence de la suppression d'un agenda : ses rendez-vous disparaissent.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Il ne contient aucun rendez-vous.} =1{Son rendez-vous sera supprimé avec lui, définitivement.} other{Ses {count} rendez-vous seront supprimés avec lui, définitivement.}}'**
  String deleteCalendarBody(int count);

  /// Confirmation après la suppression d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda supprimé.'**
  String get calendarDeleted;

  /// Explique pourquoi le dernier agenda n'a pas de bouton de suppression.
  ///
  /// In fr, this message translates to:
  /// **'Votre seul agenda ne peut pas être supprimé.'**
  String get lastCalendarHint;

  /// Choix de l'agenda où ranger un rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get eventCalendarLabel;

  /// Question posée après avoir glissé une occurrence d'un rendez-vous répété.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer seulement cette occurrence, ou toute la série ?'**
  String get scopeMoveBody;

  /// Précision quand on change l'agenda d'un rendez-vous répété : une occurrence seule ne peut pas changer d'agenda.
  ///
  /// In fr, this message translates to:
  /// **'Changer d\'agenda s\'applique toujours à toute la série.'**
  String get scopeCalendarMoveNote;

  /// Confirmation après un glisser-déposer.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous déplacé.'**
  String get eventMoved;

  /// Code d'invitation refusé ; le serveur ne dit pas pourquoi.
  ///
  /// In fr, this message translates to:
  /// **'Ce code d\'invitation n\'est pas valable : inconnu, expiré ou déjà utilisé.'**
  String get errorInvalidInvite;

  /// Action sur un groupe dont on n'est pas membre.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne faites pas partie de ce groupe.'**
  String get errorNotGroupMember;

  /// Action réservée au propriétaire du groupe.
  ///
  /// In fr, this message translates to:
  /// **'Seul le propriétaire du groupe peut faire cela.'**
  String get errorNotGroupOwner;

  /// Rôle ou transmission visant quelqu'un hors du groupe (ou le propriétaire).
  ///
  /// In fr, this message translates to:
  /// **'Cette personne ne fait pas partie du groupe.'**
  String get errorInvalidMember;

  /// Onglet de l'agenda personnel.
  ///
  /// In fr, this message translates to:
  /// **'Agenda'**
  String get navAgenda;

  /// Onglet des groupes.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get navGroups;

  /// Titre de l'écran des groupes.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groupsTitle;

  /// Liste des groupes vide.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe pour l\'instant. Créez-en un, ou rejoignez celui d\'un proche avec son code.'**
  String get noGroups;

  /// Bouton de création d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get newGroupButton;

  /// Bouton pour saisir un code d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre avec un code'**
  String get joinWithCodeButton;

  /// Rôle : propriétaire du groupe.
  ///
  /// In fr, this message translates to:
  /// **'Propriétaire'**
  String get groupRoleOwner;

  /// Rôle : administrateur du groupe.
  ///
  /// In fr, this message translates to:
  /// **'Admin'**
  String get groupRoleAdmin;

  /// Rôle : simple membre.
  ///
  /// In fr, this message translates to:
  /// **'Membre'**
  String get groupRoleMember;

  /// Sous-titre d'un groupe : ce que l'utilisateur y partage.
  ///
  /// In fr, this message translates to:
  /// **'Vous partagez : {level}'**
  String groupMyShare(String level);

  /// Titre du formulaire de création d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get newGroupTitle;

  /// Champ du nom d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Nom du groupe'**
  String get groupNameLabel;

  /// Champ de la description d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Description (facultative)'**
  String get groupDescriptionLabel;

  /// Erreur de saisie : nom de groupe vide ou trop long.
  ///
  /// In fr, this message translates to:
  /// **'Entre 1 et 60 caractères.'**
  String get validationGroupName;

  /// Bouton de création.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get createButton;

  /// Confirmation après la création d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Groupe créé.'**
  String get groupCreated;

  /// Titre de l'écran pour rejoindre un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre un groupe'**
  String get joinTitle;

  /// Champ du code d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'invitation'**
  String get inviteCodeLabel;

  /// Bouton pour passer à l'étape suivante.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueButton;

  /// Question avant de rejoindre un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre « {name} » ?'**
  String joinGroupQuestion(String name);

  /// Taille du groupe à rejoindre.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 membre} other{{count} membres}}'**
  String joinMemberCount(int count);

  /// Question du niveau de partage, posée en rejoignant.
  ///
  /// In fr, this message translates to:
  /// **'Que verront les autres membres de votre agenda ?'**
  String get joinShareQuestion;

  /// Niveau de partage : les détails des rdv.
  ///
  /// In fr, this message translates to:
  /// **'Tout : titres et lieux'**
  String get shareDetails;

  /// Niveau de partage : seulement les créneaux pris.
  ///
  /// In fr, this message translates to:
  /// **'Occupé, sans détail'**
  String get shareBusy;

  /// Niveau de partage : rien de son agenda.
  ///
  /// In fr, this message translates to:
  /// **'Rien'**
  String get shareNothing;

  /// Précision sous le choix du partage.
  ///
  /// In fr, this message translates to:
  /// **'Vous pourrez changer ce choix à tout moment dans le groupe. Vos agendas et rendez-vous masqués restent masqués.'**
  String get shareHint;

  /// Bouton pour rejoindre le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinButton;

  /// L'invitation vise un groupe dont on est membre.
  ///
  /// In fr, this message translates to:
  /// **'Vous faites déjà partie de ce groupe.'**
  String get alreadyMember;

  /// Bouton qui ouvre le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le groupe'**
  String get openGroupButton;

  /// Confirmation après avoir rejoint un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue dans « {name} » !'**
  String joinedGroup(String name);

  /// Infobulle du bouton des membres.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get groupMembersTooltip;

  /// Infobulle du bouton d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Inviter'**
  String get inviteTooltip;

  /// Désigne l'utilisateur dans la liste des membres.
  ///
  /// In fr, this message translates to:
  /// **'Vous'**
  String get memberYou;

  /// Créneau d'un membre qui ne partage pas le détail.
  ///
  /// In fr, this message translates to:
  /// **'Occupé'**
  String get busyLabel;

  /// Auteur d'un rdv de l'agenda du groupe.
  ///
  /// In fr, this message translates to:
  /// **'Groupe'**
  String get groupEventOwner;

  /// Entrée de menu : renommer le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Renommer le groupe'**
  String get renameGroup;

  /// Confirmation après avoir renommé le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Groupe enregistré.'**
  String get groupSaved;

  /// Entrée de menu : quitter le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Quitter le groupe'**
  String get leaveGroup;

  /// Titre de la confirmation pour quitter un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Quitter « {name} » ?'**
  String leaveGroupTitle(String name);

  /// Conséquence du départ d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous ne verrez plus l\'agenda du groupe, et le groupe ne verra plus le vôtre.'**
  String get leaveGroupBody;

  /// Confirmation après avoir quitté un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez quitté le groupe.'**
  String get leftGroup;

  /// Le propriétaire ne quitte pas sans transmettre.
  ///
  /// In fr, this message translates to:
  /// **'Transmettez d\'abord le groupe à un autre membre pour pouvoir le quitter.'**
  String get ownerMustTransfer;

  /// Entrée de menu : supprimer le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le groupe'**
  String get deleteGroup;

  /// Titre de la confirmation de suppression d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer « {name} » ?'**
  String deleteGroupTitle(String name);

  /// Conséquence de la suppression d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe disparaît pour tous ses membres. Leurs agendas personnels ne sont pas touchés.'**
  String get deleteGroupBody;

  /// Confirmation après la suppression d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Groupe supprimé.'**
  String get groupDeleted;

  /// Titre de l'écran des membres.
  ///
  /// In fr, this message translates to:
  /// **'Membres'**
  String get membersTitle;

  /// Libellé du réglage de partage de l'utilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Ce que je partage avec ce groupe'**
  String get myShareLabel;

  /// Ce qu'un membre partage avec le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Partage : {level}'**
  String memberShares(String level);

  /// Action : donner le rôle d'admin.
  ///
  /// In fr, this message translates to:
  /// **'Nommer admin'**
  String get makeAdmin;

  /// Action : retirer le rôle d'admin.
  ///
  /// In fr, this message translates to:
  /// **'Retirer le rôle d\'admin'**
  String get removeAdmin;

  /// Action : faire d'un membre le propriétaire.
  ///
  /// In fr, this message translates to:
  /// **'Transmettre le groupe'**
  String get transferGroup;

  /// Titre de la confirmation de transmission.
  ///
  /// In fr, this message translates to:
  /// **'Transmettre le groupe à {name} ?'**
  String transferTitle(String name);

  /// Conséquence de la transmission du groupe.
  ///
  /// In fr, this message translates to:
  /// **'{name} en deviendra propriétaire ; vous resterez admin.'**
  String transferBody(String name);

  /// Action : exclure un membre.
  ///
  /// In fr, this message translates to:
  /// **'Exclure du groupe'**
  String get removeMember;

  /// Titre de la confirmation d'exclusion.
  ///
  /// In fr, this message translates to:
  /// **'Exclure {name} ?'**
  String removeMemberTitle(String name);

  /// Confirmation après une exclusion.
  ///
  /// In fr, this message translates to:
  /// **'Membre exclu.'**
  String get memberRemoved;

  /// Confirmation après un changement de rôle.
  ///
  /// In fr, this message translates to:
  /// **'Rôle mis à jour.'**
  String get roleChanged;

  /// Confirmation après la transmission du groupe.
  ///
  /// In fr, this message translates to:
  /// **'Groupe transmis.'**
  String get groupTransferred;

  /// Confirmation après le changement de son partage.
  ///
  /// In fr, this message translates to:
  /// **'Partage enregistré.'**
  String get shareSaved;

  /// Titre de la fenêtre d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Inviter dans « {name} »'**
  String inviteTitle(String name);

  /// Précision sous le code d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Toute personne qui a ce code peut rejoindre le groupe jusqu\'au {date}.'**
  String inviteCodeHint(String date);

  /// Bouton qui copie le code d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Copier le code'**
  String get copyCode;

  /// Bouton qui copie le lien d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Copier le lien'**
  String get copyLink;

  /// Confirmation après la copie du code.
  ///
  /// In fr, this message translates to:
  /// **'Code copié.'**
  String get codeCopied;

  /// Confirmation après la copie du lien.
  ///
  /// In fr, this message translates to:
  /// **'Lien copié.'**
  String get linkCopied;

  /// Bouton qui révoque l'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Désactiver ce code'**
  String get revokeInvite;

  /// Confirmation après la révocation d'une invitation.
  ///
  /// In fr, this message translates to:
  /// **'Code désactivé.'**
  String get inviteRevoked;

  /// Le serveur refuse le lien d'import d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien n\'est pas un lien d\'agenda valable : il doit commencer par https:// ou webcal://.'**
  String get errorInvalidFeedUrl;

  /// Nombre maximal d'agendas importés atteint.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez déjà importé 10 agendas : supprimez-en un pour en ajouter un autre.'**
  String get errorTooManyFeeds;

  /// Titre de l'écran d'import et de l'entrée qui l'ouvre dans « Mes agendas ».
  ///
  /// In fr, this message translates to:
  /// **'Importer un agenda'**
  String get importCalendarTitle;

  /// Sous-titre de l'entrée « Importer un agenda ».
  ///
  /// In fr, this message translates to:
  /// **'Google, Outlook, Apple… par son lien iCal'**
  String get importCalendarHint;

  /// Bouton qui valide l'import d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get importCalendarButton;

  /// Champ du lien d'un agenda à importer.
  ///
  /// In fr, this message translates to:
  /// **'Lien iCal de l\'agenda'**
  String get importUrlLabel;

  /// Rassure sur le lien d'import, qui est un secret.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien ouvre tout votre agenda : il reste sur le serveur d\'Agora, qui ne le montre à personne, pas même à vos groupes.'**
  String get importUrlPrivacy;

  /// Erreur de saisie du lien d'import.
  ///
  /// In fr, this message translates to:
  /// **'Collez un lien qui commence par https:// ou webcal://, sans espace.'**
  String get validationFeedUrl;

  /// Titre de l'aide qui explique où trouver le lien iCal.
  ///
  /// In fr, this message translates to:
  /// **'Où trouver ce lien ?'**
  String get importHelpTitle;

  /// Où trouver le lien iCal dans Google Agenda.
  ///
  /// In fr, this message translates to:
  /// **'Sur ordinateur : Paramètres → votre agenda → Intégrer l\'agenda → « Adresse secrète au format iCal ».'**
  String get importHelpGoogle;

  /// Où trouver le lien iCal dans Outlook.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres → Calendrier → Calendriers partagés → Publier un calendrier → choisissez l\'agenda, puis copiez le lien ICS.'**
  String get importHelpOutlook;

  /// Où trouver le lien iCal dans Apple Calendrier (iCloud).
  ///
  /// In fr, this message translates to:
  /// **'App Calendrier → partager l\'agenda → cochez « Calendrier public » → copiez le lien webcal://.'**
  String get importHelpApple;

  /// Fréquence de relecture d'un agenda importé, et lecture seule.
  ///
  /// In fr, this message translates to:
  /// **'Agora relit l\'agenda toutes les 30 minutes. Ses rendez-vous sont en lecture seule : on les modifie dans l\'agenda d\'origine.'**
  String get importHelpRefresh;

  /// Confirmation après l'import d'un agenda.
  ///
  /// In fr, this message translates to:
  /// **'Agenda importé : ses rendez-vous arrivent dans un instant.'**
  String get calendarImported;

  /// Précise dans l'éditeur qu'un agenda est importé.
  ///
  /// In fr, this message translates to:
  /// **'Importé par lien iCal'**
  String get importedCalendarLabel;

  /// Bouton qui relance la synchro d'un agenda importé.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser maintenant'**
  String get syncNowButton;

  /// Confirmation après une demande de synchro.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation demandée.'**
  String get syncRequested;

  /// État d'un agenda importé pas encore relu.
  ///
  /// In fr, this message translates to:
  /// **'Première synchronisation en cours…'**
  String get syncPending;

  /// Dernière synchro réussie d'un agenda importé.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisé le {when}'**
  String syncedAt(String when);

  /// Échec de synchro : serveur de l'agenda injoignable.
  ///
  /// In fr, this message translates to:
  /// **'Lien injoignable pour l\'instant ; nouvel essai bientôt.'**
  String get syncErrorUnreachable;

  /// Échec de synchro : délai dépassé.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur de l\'agenda ne répond pas ; nouvel essai bientôt.'**
  String get syncErrorTimeout;

  /// Échec de synchro : 404.
  ///
  /// In fr, this message translates to:
  /// **'Lien introuvable : l\'agenda a été supprimé ou son lien a changé.'**
  String get syncErrorNotFound;

  /// Échec de synchro : 401 ou 403.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé : ce lien n\'est plus valable.'**
  String get syncErrorForbidden;

  /// Échec de synchro : autre erreur HTTP.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur de l\'agenda a répondu par une erreur ; nouvel essai bientôt.'**
  String get syncErrorHttp;

  /// Échec de synchro : flux trop gros.
  ///
  /// In fr, this message translates to:
  /// **'Agenda trop volumineux (plus de 5 Mo).'**
  String get syncErrorTooLarge;

  /// Échec de synchro : contenu illisible.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien ne mène pas à un agenda iCal.'**
  String get syncErrorNotCalendar;

  /// Échec de synchro : adresse interne bloquée (protection SSRF).
  ///
  /// In fr, this message translates to:
  /// **'Ce lien mène à une adresse privée, refusée par Agora.'**
  String get syncErrorBlockedAddress;

  /// Échec de synchro : trop de rendez-vous.
  ///
  /// In fr, this message translates to:
  /// **'Agenda trop chargé : plus de 5 000 rendez-vous à importer.'**
  String get syncErrorTooManyEvents;

  /// Échec de synchro de cause inconnue.
  ///
  /// In fr, this message translates to:
  /// **'La dernière synchronisation a échoué.'**
  String get syncErrorUnknown;

  /// Explique sur la fiche d'un rdv importé ce qu'on peut y faire.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous importé : modifiez-le dans l\'agenda d\'origine. Vous choisissez ici ce qu\'en voient vos groupes.'**
  String get importedEventReadOnly;

  /// Le réglage de visibilité d'une occurrence importée vaut pour la série.
  ///
  /// In fr, this message translates to:
  /// **'S\'applique à toute la série.'**
  String get importedEventSeriesNote;

  /// Confirmation après le réglage de visibilité d'un rdv importé.
  ///
  /// In fr, this message translates to:
  /// **'Réglage enregistré.'**
  String get eventVisibilitySaved;

  /// Bouton de l'agenda d'un groupe : proposer un rendez-vous au groupe.
  ///
  /// In fr, this message translates to:
  /// **'Proposer un rdv'**
  String get proposeEventButton;

  /// Confirmation après la création d'un rendez-vous de groupe.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous proposé au groupe.'**
  String get eventProposed;

  /// Titre du choix de sa réponse à un rendez-vous de groupe.
  ///
  /// In fr, this message translates to:
  /// **'Ma réponse'**
  String get myResponseLabel;

  /// Réponse à un rendez-vous de groupe : je viens.
  ///
  /// In fr, this message translates to:
  /// **'Présent'**
  String get responseYes;

  /// Réponse à un rendez-vous de groupe : peut-être.
  ///
  /// In fr, this message translates to:
  /// **'Peut-être'**
  String get responseMaybe;

  /// Réponse à un rendez-vous de groupe : je ne viens pas.
  ///
  /// In fr, this message translates to:
  /// **'Absent'**
  String get responseNo;

  /// Membres qui n'ont pas encore répondu.
  ///
  /// In fr, this message translates to:
  /// **'Sans réponse'**
  String get responseNone;

  /// Titre de la liste des réponses des membres.
  ///
  /// In fr, this message translates to:
  /// **'Réponses'**
  String get responsesTitle;

  /// Une catégorie de réponses et son nombre de membres.
  ///
  /// In fr, this message translates to:
  /// **'{label} · {count}'**
  String responseSectionTitle(String label, int count);

  /// Auteur d'un rendez-vous de groupe.
  ///
  /// In fr, this message translates to:
  /// **'Proposé par {name}'**
  String proposedBy(String name);

  /// Confirmation après une réponse à un rendez-vous de groupe.
  ///
  /// In fr, this message translates to:
  /// **'Réponse enregistrée.'**
  String get responseSaved;

  /// Confirmation après le retrait de sa réponse.
  ///
  /// In fr, this message translates to:
  /// **'Réponse retirée.'**
  String get responseRemoved;

  /// Précise qu'on répond occurrence par occurrence.
  ///
  /// In fr, this message translates to:
  /// **'Rendez-vous répété : votre réponse vaut pour cette date.'**
  String get occurrenceResponseNote;

  /// Titre de la section des agendas de groupe dans « Mes agendas ».
  ///
  /// In fr, this message translates to:
  /// **'Agendas de mes groupes'**
  String get groupCalendarsTitle;

  /// Auteur d'un rendez-vous de groupe quand c'est l'utilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Proposé par vous'**
  String get proposedByMe;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
