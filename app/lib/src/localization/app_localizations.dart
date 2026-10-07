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
  /// **'Tes agendas, ensemble.'**
  String get homeTagline;

  /// Salutation de l'accueil, avec le nom affiché du profil.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, {name} !'**
  String homeGreeting(String name);

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

  /// Explication sous le titre de la confirmation d'adresse. Ne pas affirmer qu'un code est parti : pour une adresse déjà inscrite, rien n'est envoyé, et l'écran ne doit pas le révéler.
  ///
  /// In fr, this message translates to:
  /// **'Saisis le code à 6 chiffres envoyé à {email}.'**
  String verifyEmailInstructions(String email);

  /// Indication affichée à tous sur l'écran du code d'inscription : l'inscription répond pareil qu'une adresse ait un compte ou non, c'est ce texte qui oriente le titulaire sans rien révéler.
  ///
  /// In fr, this message translates to:
  /// **'Cette adresse a déjà un compte ? Aucun code n’arrivera : connecte-toi, ou passe par « Mot de passe oublié ».'**
  String get verifyEmailExistingAccountHint;

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

  /// Le serveur a refusé le jeton « je ne suis pas un robot » (absent, périmé ou déjà utilisé).
  ///
  /// In fr, this message translates to:
  /// **'La vérification a échoué. Réessaie dans un instant.'**
  String get errorCaptchaFailed;

  /// Avertissement du dialogue de suppression : ce qui survit au compte.
  ///
  /// In fr, this message translates to:
  /// **'Ces rdv que tu as proposés resteront à leurs groupes, sans auteur, mais avec leur texte :'**
  String get deleteAccountLeftBehind;

  /// Une ligne de la liste des rdv qui resteront : titre et nom du groupe.
  ///
  /// In fr, this message translates to:
  /// **'{title} — {group}'**
  String deleteAccountLeftBehindItem(String title, String group);

  /// Fin de la liste des rdv qui resteront, quand elle est tronquée.
  ///
  /// In fr, this message translates to:
  /// **'et {count} autres'**
  String deleteAccountLeftBehindMore(int count);

  /// Case à cocher qui efface les rdv proposés avant de supprimer le compte.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer aussi ces rdv'**
  String get deleteAccountAlsoEvents;

  /// Titre de la section du profil qui renvoie aux pages légales.
  ///
  /// In fr, this message translates to:
  /// **'Informations légales'**
  String get legalSectionTitle;

  /// Lien vers la politique de confidentialité, ouverte dans le navigateur.
  ///
  /// In fr, this message translates to:
  /// **'Politique de confidentialité'**
  String get legalPrivacy;

  /// Lien vers les mentions légales (éditeur, hébergeur), ouvertes dans le navigateur.
  ///
  /// In fr, this message translates to:
  /// **'Mentions légales'**
  String get legalNotice;

  /// Lien vers les conditions d'utilisation, ouvertes dans le navigateur.
  ///
  /// In fr, this message translates to:
  /// **'Conditions d\'utilisation'**
  String get legalTerms;

  /// Message quand l'appareil n'a pas su ouvrir le lien d'une page légale.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir cette page.'**
  String get legalLinkFailed;

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

  /// Période affichée sous la navigation de l'agenda, quand ses jours tiennent dans un mois (ex. « 5 – 11 octobre 2026 »). first et last : numéros du premier et du dernier jour ; month : nom du mois en toutes lettres ; year : l'année.
  ///
  /// In fr, this message translates to:
  /// **'{first} – {last} {month} {year}'**
  String agendaPeriodSameMonth(
    String first,
    String last,
    String month,
    String year,
  );

  /// Période affichée sous la navigation de l'agenda, quand ses jours couvrent deux mois d'une même année (ex. « 28 sept. – 4 oct. 2026 »). first et last : jour et mois abrégé, déjà formatés ; year : l'année.
  ///
  /// In fr, this message translates to:
  /// **'{first} – {last} {year}'**
  String agendaPeriodSameYear(String first, String last, String year);

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
  /// **'Garde au moins un agenda : c\'est là que se rangent tes nouveaux rendez-vous.'**
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
  /// **'Ton seul agenda ne peut pas être supprimé.'**
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
  /// **'Tu ne fais pas partie de ce groupe.'**
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

  /// Titre de l'écran des groupes.
  ///
  /// In fr, this message translates to:
  /// **'Groupes'**
  String get groupsTitle;

  /// Liste des groupes vide.
  ///
  /// In fr, this message translates to:
  /// **'Aucun groupe pour l\'instant. Crées-en un, ou rejoins celui d\'un proche avec son code.'**
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
  /// **'Tu partages : {level}'**
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
  /// **'Que verront les autres membres de ton agenda ?'**
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
  /// **'Tu pourras changer ce choix à tout moment dans le groupe. Tes agendas et rendez-vous masqués restent masqués.'**
  String get shareHint;

  /// Bouton pour rejoindre le groupe.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get joinButton;

  /// L'invitation vise un groupe dont on est membre.
  ///
  /// In fr, this message translates to:
  /// **'Tu fais déjà partie de ce groupe.'**
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
  /// **'Toi'**
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
  /// **'Tu ne verras plus l\'agenda du groupe, et le groupe ne verra plus le tien.'**
  String get leaveGroupBody;

  /// Confirmation après avoir quitté un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Tu as quitté le groupe.'**
  String get leftGroup;

  /// Le propriétaire ne quitte pas sans transmettre.
  ///
  /// In fr, this message translates to:
  /// **'Transmets d\'abord le groupe à un autre membre pour pouvoir le quitter.'**
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
  /// **'{name} en deviendra propriétaire ; tu resteras admin.'**
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
  /// **'Tu as déjà importé 10 agendas : supprimes-en un pour en ajouter un autre.'**
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
  /// **'Ce lien ouvre tout ton agenda : il reste sur le serveur d\'Agora, qui ne le montre à personne, pas même à tes groupes.'**
  String get importUrlPrivacy;

  /// Erreur de saisie du lien d'import.
  ///
  /// In fr, this message translates to:
  /// **'Colle un lien qui commence par https:// ou webcal://, sans espace.'**
  String get validationFeedUrl;

  /// Titre de l'aide qui explique où trouver le lien iCal.
  ///
  /// In fr, this message translates to:
  /// **'Où trouver ce lien ?'**
  String get importHelpTitle;

  /// Où trouver le lien iCal dans Google Agenda.
  ///
  /// In fr, this message translates to:
  /// **'Sur ordinateur : Paramètres → ton agenda → Intégrer l\'agenda → « Adresse secrète au format iCal ».'**
  String get importHelpGoogle;

  /// Où trouver le lien iCal dans Outlook.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres → Calendrier → Calendriers partagés → Publier un calendrier → choisis l\'agenda, puis copie le lien ICS.'**
  String get importHelpOutlook;

  /// Où trouver le lien iCal dans Apple Calendrier (iCloud).
  ///
  /// In fr, this message translates to:
  /// **'App Calendrier → partager l\'agenda → coche « Calendrier public » → copie le lien webcal://.'**
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
  /// **'Rendez-vous importé : modifie-le dans l\'agenda d\'origine. Tu choisis ici ce qu\'en voient tes groupes.'**
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
  /// **'Rendez-vous répété : ta réponse vaut pour cette date.'**
  String get occurrenceResponseNote;

  /// Auteur d'un rendez-vous de groupe quand c'est l'utilisateur.
  ///
  /// In fr, this message translates to:
  /// **'Proposé par toi'**
  String get proposedByMe;

  /// Bouton de l'agenda d'un groupe : chercher un créneau commun.
  ///
  /// In fr, this message translates to:
  /// **'Trouver un créneau'**
  String get findSlotTooltip;

  /// Titre de l'écran de recherche de créneaux libres pour tous.
  ///
  /// In fr, this message translates to:
  /// **'Créneaux communs'**
  String get findSlotTitle;

  /// Durée du rendez-vous à caler.
  ///
  /// In fr, this message translates to:
  /// **'Durée'**
  String get slotDurationLabel;

  /// Période où chercher un créneau.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get slotPeriodLabel;

  /// Choix de la période : les N prochains jours.
  ///
  /// In fr, this message translates to:
  /// **'{count} prochains jours'**
  String slotPeriodDays(int count);

  /// Heure à partir de laquelle chercher, chaque jour.
  ///
  /// In fr, this message translates to:
  /// **'Pas avant'**
  String get slotNotBeforeLabel;

  /// Heure jusqu'à laquelle chercher, chaque jour.
  ///
  /// In fr, this message translates to:
  /// **'Pas après'**
  String get slotNotAfterLabel;

  /// Chercher aussi le samedi et le dimanche.
  ///
  /// In fr, this message translates to:
  /// **'Week-ends compris'**
  String get slotWeekendsLabel;

  /// Un rdv sur la journée entière (anniversaire, vacances) rend-il indisponible ?
  ///
  /// In fr, this message translates to:
  /// **'Les journées entières comptent comme prises'**
  String get slotAllDayLabel;

  /// Membres dont la présence est requise.
  ///
  /// In fr, this message translates to:
  /// **'Qui doit être là'**
  String get slotMembersLabel;

  /// Avertit que les membres qui ne partagent rien ne peuvent pas être vérifiés.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{names} ne partage pas son agenda avec le groupe : cette personne paraît toujours libre.} other{{names} ne partagent pas leur agenda avec le groupe : ces personnes paraissent toujours libres.}}'**
  String slotInvisibleNote(String names, int count);

  /// Rappel de ce que la recherche prend en compte.
  ///
  /// In fr, this message translates to:
  /// **'Seul ce que chacun partage avec le groupe compte ; un rdv du groupe prend le créneau.'**
  String get slotsHint;

  /// Aucun créneau trouvé.
  ///
  /// In fr, this message translates to:
  /// **'Aucun créneau libre pour tout le monde sur cette période.'**
  String get slotsNone;

  /// Durée en minutes.
  ///
  /// In fr, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// Durée en heures pleines.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h'**
  String durationHours(int hours);

  /// Durée en heures et minutes.
  ///
  /// In fr, this message translates to:
  /// **'{hours} h {minutes}'**
  String durationHoursMinutes(int hours, int minutes);

  /// Volet repliable des critères secondaires de la recherche de créneaux.
  ///
  /// In fr, this message translates to:
  /// **'Heures, jours et membres'**
  String get slotMoreCriteria;

  /// Action réservée aux admins du groupe (salon Discord).
  ///
  /// In fr, this message translates to:
  /// **'Seul un admin du groupe peut faire cela.'**
  String get errorNotGroupAdmin;

  /// Liaison refusée : le compte Discord appartient déjà à quelqu'un d'autre sur Agora.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte Discord est déjà relié à un autre compte Agora.'**
  String get errorDiscordAlreadyLinked;

  /// Titre de la section Discord du profil.
  ///
  /// In fr, this message translates to:
  /// **'Discord'**
  String get discordSectionTitle;

  /// Compte Discord relié ; name est le nom Discord.
  ///
  /// In fr, this message translates to:
  /// **'Relié à {name}'**
  String discordAccountLinked(String name);

  /// Profil : le compte Discord n'est pas relié.
  ///
  /// In fr, this message translates to:
  /// **'Relie ton compte Discord pour utiliser /agenda et /dispo avec le bot Agora.'**
  String get discordAccountNotLinked;

  /// Bouton qui ouvre la liaison du compte Discord.
  ///
  /// In fr, this message translates to:
  /// **'Relier Discord'**
  String get discordLinkButton;

  /// Bouton qui retire la liaison du compte Discord.
  ///
  /// In fr, this message translates to:
  /// **'Délier'**
  String get discordUnlinkButton;

  /// La page de liaison Discord n'a pas pu s'ouvrir.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir Discord.'**
  String get discordLinkFailed;

  /// Titre de la ligne Google du profil (section Connexions).
  ///
  /// In fr, this message translates to:
  /// **'Google'**
  String get googleSectionTitle;

  /// Compte Google relié ; account est son adresse.
  ///
  /// In fr, this message translates to:
  /// **'Relié à {account}'**
  String googleAccountLinked(String account);

  /// Compte ouvert par Google, qui n'a pas d'autre moyen de connexion : il ne se délie pas.
  ///
  /// In fr, this message translates to:
  /// **'Tu te connectes avec {account}.'**
  String googleAccountOnlyWayIn(String account);

  /// Profil : aucun compte Google relié.
  ///
  /// In fr, this message translates to:
  /// **'Relie ton compte Google pour te connecter en un geste.'**
  String get googleAccountNotLinked;

  /// Bouton qui ouvre la liaison du compte Google.
  ///
  /// In fr, this message translates to:
  /// **'Relier Google'**
  String get googleLinkButton;

  /// Bouton qui retire la liaison du compte Google.
  ///
  /// In fr, this message translates to:
  /// **'Délier'**
  String get googleUnlinkButton;

  /// La page de liaison Google n'a pas pu s'ouvrir.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir Google.'**
  String get googleLinkFailed;

  /// Liaison refusée : le compte Google appartient déjà à quelqu'un d'autre sur Agora.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte Google est déjà relié à un autre compte Agora.'**
  String get errorGoogleAlreadyLinked;

  /// Délier refusé : le compte n'aurait plus aucun moyen de connexion.
  ///
  /// In fr, this message translates to:
  /// **'C\'est ton seul moyen de te connecter : il ne peut pas être délié.'**
  String get errorLastSignInMethod;

  /// Entrée du menu d'un groupe qui ouvre le réglage du salon Discord.
  ///
  /// In fr, this message translates to:
  /// **'Salon Discord'**
  String get groupDiscordMenu;

  /// Titre de l'écran du salon Discord d'un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Salon Discord'**
  String get discordChannelTitle;

  /// Écran salon Discord : aucun salon relié.
  ///
  /// In fr, this message translates to:
  /// **'Aucun salon Discord n\'est relié à ce groupe.'**
  String get discordChannelNone;

  /// Écran salon Discord, vu par un simple membre.
  ///
  /// In fr, this message translates to:
  /// **'Un admin du groupe peut en relier un.'**
  String get discordChannelAskAdmin;

  /// Nom du salon relié.
  ///
  /// In fr, this message translates to:
  /// **'Relié à #{name}'**
  String discordChannelLinked(String name);

  /// Salon relié dont Discord n'a pas donné le nom.
  ///
  /// In fr, this message translates to:
  /// **'Relié à un salon Discord'**
  String get discordChannelLinkedUnnamed;

  /// Mode d'emploi de la liaison d'un salon.
  ///
  /// In fr, this message translates to:
  /// **'Invite le bot sur ton serveur, puis crée un code et tape la commande dans le salon voulu. Il faut pouvoir gérer ce salon.'**
  String get discordLinkSteps;

  /// Bouton qui ouvre l'installation du bot Discord.
  ///
  /// In fr, this message translates to:
  /// **'Inviter le bot sur un serveur'**
  String get discordInviteBot;

  /// Bouton qui crée le code à taper dans Discord.
  ///
  /// In fr, this message translates to:
  /// **'Créer un code de liaison'**
  String get discordCreateCode;

  /// Consigne affichée au-dessus de la commande à taper.
  ///
  /// In fr, this message translates to:
  /// **'Dans les 10 minutes, tape dans le salon à relier :'**
  String get discordCodeInstructions;

  /// Commande Discord qui relie un salon ; code est le code de liaison.
  ///
  /// In fr, this message translates to:
  /// **'/relier {code}'**
  String discordLinkCommand(String code);

  /// Bouton qui copie la commande.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get discordCopyCommand;

  /// Confirmation de copie de la commande.
  ///
  /// In fr, this message translates to:
  /// **'Commande copiée.'**
  String get discordCommandCopied;

  /// Bouton qui relit l'état du salon après la commande dans Discord.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai tapé la commande'**
  String get discordCheckLink;

  /// Réglage du récap publié dans le salon.
  ///
  /// In fr, this message translates to:
  /// **'Récap dans le salon'**
  String get discordRecapLabel;

  /// Pas de récap.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get discordRecapOff;

  /// Récap quotidien.
  ///
  /// In fr, this message translates to:
  /// **'Chaque jour'**
  String get discordRecapDaily;

  /// Récap hebdomadaire.
  ///
  /// In fr, this message translates to:
  /// **'Chaque semaine'**
  String get discordRecapWeekly;

  /// Jour du récap hebdomadaire.
  ///
  /// In fr, this message translates to:
  /// **'Jour'**
  String get discordRecapDay;

  /// Heure du récap.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get discordRecapHour;

  /// Heure pleine.
  ///
  /// In fr, this message translates to:
  /// **'{hour} h'**
  String discordRecapHourValue(int hour);

  /// Fuseau dans lequel s'entend l'heure du récap.
  ///
  /// In fr, this message translates to:
  /// **'Heures de {timezone}'**
  String discordRecapTimezone(String timezone);

  /// Réglage des rappels.
  ///
  /// In fr, this message translates to:
  /// **'Rappel avant les rdv du groupe'**
  String get discordReminderLabel;

  /// Pas de rappel.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get discordReminderOff;

  /// Rappel 15 minutes avant.
  ///
  /// In fr, this message translates to:
  /// **'15 min avant'**
  String get discordReminder15;

  /// Rappel une heure avant.
  ///
  /// In fr, this message translates to:
  /// **'1 h avant'**
  String get discordReminder60;

  /// Rappel 24 heures avant.
  ///
  /// In fr, this message translates to:
  /// **'La veille'**
  String get discordReminder1440;

  /// Avertissement sur ce que voit un salon Discord.
  ///
  /// In fr, this message translates to:
  /// **'Tout le salon voit les récaps et les rappels, même des personnes hors du groupe : les rdv du groupe y figurent en détail, les rdv personnels seulement comme « occupé ».'**
  String get discordPublicNotice;

  /// Confirmation d'enregistrement des réglages Discord.
  ///
  /// In fr, this message translates to:
  /// **'Réglages enregistrés.'**
  String get discordSaved;

  /// Bouton qui délie le salon Discord du groupe.
  ///
  /// In fr, this message translates to:
  /// **'Délier le salon'**
  String get discordUnlinkChannel;

  /// Bouton d'une fiche de rdv qui ouvre l'itinéraire vers son lieu.
  ///
  /// In fr, this message translates to:
  /// **'Y aller'**
  String get goThereButton;

  /// Titre de la feuille d'itinéraire.
  ///
  /// In fr, this message translates to:
  /// **'Y aller en transports'**
  String get goThereTitle;

  /// Heure d'arrivée visée : le début du rdv.
  ///
  /// In fr, this message translates to:
  /// **'Pour arriver le {when}'**
  String goThereArriveBy(String when);

  /// Champ de l'adresse de départ, pré-rempli par le domicile s'il y en a un.
  ///
  /// In fr, this message translates to:
  /// **'Départ'**
  String get goThereOriginLabel;

  /// Aide du champ de départ : vide, c'est la position ; ce qu'on y tape n'est pas gardé.
  ///
  /// In fr, this message translates to:
  /// **'Vide : depuis ta position. Une adresse tapée ici n\'est pas enregistrée.'**
  String get goThereOriginHelper;

  /// Bulle du bouton qui vide le champ de départ : l'itinéraire part de la position du téléphone.
  ///
  /// In fr, this message translates to:
  /// **'Depuis ma position'**
  String get goThereFromMyPosition;

  /// Ouvre l'itinéraire dans Citymapper.
  ///
  /// In fr, this message translates to:
  /// **'Citymapper'**
  String get goThereCitymapper;

  /// Ouvre l'itinéraire dans Google Maps.
  ///
  /// In fr, this message translates to:
  /// **'Google Maps'**
  String get goThereGoogleMaps;

  /// Google Maps ne reçoit pas l'heure d'arrivée par lien.
  ///
  /// In fr, this message translates to:
  /// **'Dans Google Maps, règle l\'heure d\'arrivée toi-même : le lien ne peut pas la transmettre.'**
  String get goThereGoogleNote;

  /// Ouvre le lieu dans une app de cartes au choix (Android).
  ///
  /// In fr, this message translates to:
  /// **'Autre app de cartes'**
  String get goThereOtherApp;

  /// Échec de l'ouverture de l'app d'itinéraire.
  ///
  /// In fr, this message translates to:
  /// **'Aucune app n\'a pu ouvrir l\'itinéraire.'**
  String get goThereFailed;

  /// Titre de l'écran des trajets (onglet Moi) et de sa ligne dans Moi.
  ///
  /// In fr, this message translates to:
  /// **'Trajets'**
  String get travelTitle;

  /// Sous-titre de la ligne Trajets de Moi quand aucun domicile n'est posé.
  ///
  /// In fr, this message translates to:
  /// **'Aucun domicile'**
  String get travelTileNoHome;

  /// Section du domicile dans l'écran des trajets.
  ///
  /// In fr, this message translates to:
  /// **'Domicile'**
  String get travelHomeTitle;

  /// Écran des trajets, sans domicile posé.
  ///
  /// In fr, this message translates to:
  /// **'Aucun domicile enregistré : « Y aller » part de ta position.'**
  String get travelNoHome;

  /// Bulle du bouton qui efface le domicile.
  ///
  /// In fr, this message translates to:
  /// **'Effacer mon domicile'**
  String get travelClearHome;

  /// Champ de recherche du domicile.
  ///
  /// In fr, this message translates to:
  /// **'Chercher une adresse'**
  String get travelHomeSearchLabel;

  /// Aide du champ de recherche : la France seulement, et le domicile se choisit parmi les suggestions.
  ///
  /// In fr, this message translates to:
  /// **'Une adresse en France, à choisir dans les suggestions.'**
  String get travelHomeSearchHelper;

  /// La recherche d'adresses n'a rien rendu.
  ///
  /// In fr, this message translates to:
  /// **'Aucune adresse trouvée. Essaie avec le numéro, la rue et la ville.'**
  String get travelNoAddressFound;

  /// Confirmation après avoir choisi un domicile.
  ///
  /// In fr, this message translates to:
  /// **'Domicile enregistré.'**
  String get travelHomeSaved;

  /// Confirmation après avoir effacé le domicile.
  ///
  /// In fr, this message translates to:
  /// **'Domicile effacé.'**
  String get travelHomeCleared;

  /// Pied de l'écran des trajets : qui voit le domicile, à quoi il sert, et la source des adresses (attribution IGN).
  ///
  /// In fr, this message translates to:
  /// **'Toi seul vois ton domicile : ni tes groupes, ni Discord, ni un assistant IA. « Y aller » en part par défaut. Adresses : Géoplateforme de l\'IGN.'**
  String get travelHomePrivacy;

  /// Séparateur entre le formulaire et les boutons de connexion par fournisseur.
  ///
  /// In fr, this message translates to:
  /// **'ou'**
  String get orDivider;

  /// Connexion (ou création du compte) par Google.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Google'**
  String get continueWithGoogle;

  /// Connexion (ou création du compte) par Discord.
  ///
  /// In fr, this message translates to:
  /// **'Continuer avec Discord'**
  String get continueWithDiscord;

  /// La page du fournisseur n'a pas pu s'ouvrir.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir la page de connexion.'**
  String get socialSignInFailed;

  /// Erreur : demande d'accès d'un assistant IA expirée (dix minutes) ou déjà tranchée.
  ///
  /// In fr, this message translates to:
  /// **'Cette demande d\'accès a expiré ou a déjà été traitée. Relance la connexion depuis ton assistant.'**
  String get errorConsentExpired;

  /// Erreur : le serveur OAuth n'est pas allumé.
  ///
  /// In fr, this message translates to:
  /// **'Le branchement des assistants IA n\'est pas encore ouvert.'**
  String get errorAssistantsUnavailable;

  /// Titre de l'écran Assistant IA et de son entrée dans le profil.
  ///
  /// In fr, this message translates to:
  /// **'Assistant IA'**
  String get assistantTitle;

  /// Profil : sous-titre de l'entrée Assistant IA.
  ///
  /// In fr, this message translates to:
  /// **'Brancher Claude, ChatGPT… sur ton agenda'**
  String get assistantProfileSubtitle;

  /// Écran Assistant IA : ce que fait un assistant branché.
  ///
  /// In fr, this message translates to:
  /// **'Un assistant IA branché sur Agora lit ton agenda et ceux de tes groupes comme l\'app te les montre, cherche des créneaux communs, crée tes rdv, en propose à un groupe et y répond — toujours à ton nom. Il ne modifie ni ne supprime rien.'**
  String get assistantIntro;

  /// Écran Assistant IA : titre de l'adresse du serveur MCP.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du connecteur'**
  String get assistantAddressTitle;

  /// Bouton (infobulle) : copier un texte.
  ///
  /// In fr, this message translates to:
  /// **'Copier'**
  String get assistantCopy;

  /// Message : texte copié dans le presse-papiers.
  ///
  /// In fr, this message translates to:
  /// **'Copié.'**
  String get assistantCopied;

  /// Écran Assistant IA : geste pour brancher claude.ai.
  ///
  /// In fr, this message translates to:
  /// **'Dans claude.ai : Paramètres → Connecteurs → Ajouter un connecteur personnalisé, puis colle l\'adresse.'**
  String get assistantClaudeAi;

  /// Écran Assistant IA : précède la commande Claude Code.
  ///
  /// In fr, this message translates to:
  /// **'Dans Claude Code, puis /mcp → Authenticate :'**
  String get assistantClaudeCode;

  /// Écran Assistant IA : les autres assistants.
  ///
  /// In fr, this message translates to:
  /// **'ChatGPT, Cursor, VS Code : la même adresse, dans leurs réglages de connecteurs MCP.'**
  String get assistantOthers;

  /// Écran Assistant IA : lien vers la page publique.
  ///
  /// In fr, this message translates to:
  /// **'Mode d\'emploi détaillé'**
  String get assistantGuide;

  /// Écran Assistant IA : build sans adresse d'API.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de l\'app ne connaît pas l\'adresse du serveur.'**
  String get assistantNoAddress;

  /// Écran Assistant IA : titre de la liste des accès accordés.
  ///
  /// In fr, this message translates to:
  /// **'Assistants autorisés'**
  String get assistantGrantsTitle;

  /// Écran Assistant IA : la révocation est immédiate.
  ///
  /// In fr, this message translates to:
  /// **'Retirer un accès le coupe aussitôt.'**
  String get assistantRevokeImmediate;

  /// Écran Assistant IA : aucun accès accordé.
  ///
  /// In fr, this message translates to:
  /// **'Aucun assistant n\'a accès à ton agenda.'**
  String get assistantNoGrant;

  /// Accès accordé ; date est la date d'autorisation.
  ///
  /// In fr, this message translates to:
  /// **'Autorisé le {date}'**
  String assistantGrantedOn(String date);

  /// Bouton : retirer l'accès d'un assistant.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get assistantRevoke;

  /// Dialogue : confirmer le retrait d'un accès.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'accès ?'**
  String get assistantRevokeTitle;

  /// Dialogue de retrait ; name est le nom de l'assistant.
  ///
  /// In fr, this message translates to:
  /// **'{name} ne pourra plus lire ton agenda ni agir pour toi. Tu pourras l\'autoriser de nouveau depuis l\'assistant.'**
  String assistantRevokeBody(String name);

  /// Message : accès d'un assistant retiré.
  ///
  /// In fr, this message translates to:
  /// **'Accès retiré.'**
  String get assistantRevoked;

  /// Accès accordé à un client OAuth sans nom.
  ///
  /// In fr, this message translates to:
  /// **'Assistant sans nom'**
  String get assistantUnnamed;

  /// Assistant reconnu à une adresse de retour locale.
  ///
  /// In fr, this message translates to:
  /// **'un outil de cet ordinateur (Claude Code, Cursor, VS Code…)'**
  String get assistantLocalTool;

  /// Titre de l'écran de consentement.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser un assistant'**
  String get consentTitle;

  /// Consentement : la question ; assistant est le nom de l'assistant reconnu.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser {assistant} à accéder à ton agenda Agora ?'**
  String consentQuestion(String assistant);

  /// Consentement : le nom que le client se donne (jamais une preuve).
  ///
  /// In fr, this message translates to:
  /// **'Il se présente comme « {name} ».'**
  String consentPresentsAs(String name);

  /// Consentement : titre de ce que l'assistant pourra faire.
  ///
  /// In fr, this message translates to:
  /// **'Il pourra :'**
  String get consentCanTitle;

  /// Consentement : lecture.
  ///
  /// In fr, this message translates to:
  /// **'lire ton agenda et celui de tes groupes, comme l\'app te les montre ;'**
  String get consentCanRead;

  /// Consentement : créneaux.
  ///
  /// In fr, this message translates to:
  /// **'chercher des créneaux communs ;'**
  String get consentCanSlots;

  /// Consentement : écritures.
  ///
  /// In fr, this message translates to:
  /// **'créer un rdv dans ton agenda, proposer un rdv à un de tes groupes, répondre à un rdv de groupe.'**
  String get consentCanWrite;

  /// Consentement : titre de ce que l'assistant ne pourra pas faire.
  ///
  /// In fr, this message translates to:
  /// **'Il ne pourra pas :'**
  String get consentCannotTitle;

  /// Consentement : ce qui reste interdit.
  ///
  /// In fr, this message translates to:
  /// **'modifier ni supprimer un rdv, ni toucher à tes groupes, à ton partage ou à ton compte.'**
  String get consentCannot;

  /// Consentement : mise en garde.
  ///
  /// In fr, this message translates to:
  /// **'N\'autorise qu\'un assistant que tu utilises toi-même. Tu pourras retirer l\'accès à tout moment : Profil → Assistant IA.'**
  String get consentWarning;

  /// Consentement : le compte connecté ; email est son adresse.
  ///
  /// In fr, this message translates to:
  /// **'Compte : {email}'**
  String consentAccount(String email);

  /// Consentement : se déconnecter pour changer de compte.
  ///
  /// In fr, this message translates to:
  /// **'Ce n\'est pas moi'**
  String get consentNotMe;

  /// Consentement : accorder l'accès.
  ///
  /// In fr, this message translates to:
  /// **'Autoriser'**
  String get consentApprove;

  /// Consentement : refuser l'accès.
  ///
  /// In fr, this message translates to:
  /// **'Refuser'**
  String get consentDeny;

  /// Consentement : l'onglet rend la main à l'assistant.
  ///
  /// In fr, this message translates to:
  /// **'Retour vers l\'assistant…'**
  String get consentHandedOver;

  /// Consentement : l'adresse de retour n'a pas pu s'ouvrir.
  ///
  /// In fr, this message translates to:
  /// **'Le retour vers l\'assistant n\'a pas pu s\'ouvrir. Relance la connexion depuis l\'assistant.'**
  String get consentHandOverFailed;

  /// Consentement : l'utilisateur a refusé.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé.'**
  String get consentDenied;

  /// Consentement : demande d'un client dont l'adresse de retour n'est pas reconnue ; host est son hôte.
  ///
  /// In fr, this message translates to:
  /// **'Accès refusé : cette demande ne vient pas d\'un assistant reconnu ({host}).'**
  String consentUnknownAssistant(String host);

  /// Consentement : revenir à l'accueil d'Agora.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get consentHome;

  /// Partage : le niveau « Tout » vaut aussi pour les assistants IA des membres.
  ///
  /// In fr, this message translates to:
  /// **'Avec « Tout », les membres voient titres et lieux, y compris par l\'assistant IA qu\'ils ont branché sur Agora.'**
  String get shareDetailsAssistantHint;

  /// Erreur : lien de jumelage inconnu ou mal formé.
  ///
  /// In fr, this message translates to:
  /// **'Ce lien de jumelage n\'est pas valable.'**
  String get errorInvalidTwinLink;

  /// Menu du groupe (admins) : ouvre le jumelage avec d'autres apps.
  ///
  /// In fr, this message translates to:
  /// **'Jumelage'**
  String get twinMenu;

  /// Titre de l'écran et de la feuille de jumelage.
  ///
  /// In fr, this message translates to:
  /// **'Jumelage'**
  String get twinTitle;

  /// Bandeau d'un groupe jumelé ; {app} : nom de l'autre app (marque).
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe existe aussi dans {app}.'**
  String twinAlsoIn(String app);

  /// Bandeau d'un groupe jumelé : rejoindre le groupe jumeau dans l'autre app.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre'**
  String get twinJoinButton;

  /// Jumelage : ce que fait un jumeau.
  ///
  /// In fr, this message translates to:
  /// **'Un jumeau est un groupe d\'une autre app. Ses membres y voient « Rejoindre aussi dans Agora », et ceux d\'ici « Rejoindre aussi dans {app} ». Chacun rejoint lui-même : personne n\'est ajouté d\'office.'**
  String twinExplain(String app);

  /// Jumelage : lancer la demande vers l'autre app.
  ///
  /// In fr, this message translates to:
  /// **'Jumeler avec {app}'**
  String twinStartButton(String app);

  /// Jumelage lancé, sans réponse de l'autre app.
  ///
  /// In fr, this message translates to:
  /// **'En attente de la réponse de {app}. Si elle ne vient pas, relance le jumelage.'**
  String twinPending(String app);

  /// Jumelage en attente : renvoyer la demande.
  ///
  /// In fr, this message translates to:
  /// **'Relancer'**
  String get twinRestartButton;

  /// Jumelage : le groupe a un jumeau complet.
  ///
  /// In fr, this message translates to:
  /// **'Jumelé avec un groupe {app}.'**
  String twinLinked(String app);

  /// Jumelage : supprimer le jumeau (et son invitation).
  ///
  /// In fr, this message translates to:
  /// **'Défaire le jumelage'**
  String get twinUnlinkButton;

  /// Confirmation avant de défaire un jumelage.
  ///
  /// In fr, this message translates to:
  /// **'Défaire le jumelage avec {app} ?'**
  String twinUnlinkTitle(String app);

  /// Confirmation : ce que défaire change, et ce que ça ne change pas.
  ///
  /// In fr, this message translates to:
  /// **'Le code donné à {app} n\'ouvrira plus ce groupe. Dans {app}, le bouton restera affiché jusqu\'à ce qu\'on l\'y retire.'**
  String twinUnlinkBody(String app);

  /// Confirmation : jumelage défait.
  ///
  /// In fr, this message translates to:
  /// **'Jumelage défait.'**
  String get twinUnlinked;

  /// Demande de jumelage reçue d'une autre app.
  ///
  /// In fr, this message translates to:
  /// **'Le groupe {app} « {name} » propose un jumelage.'**
  String twinRequestTitle(String app, String name);

  /// Demande de jumelage reçue, sans nom de groupe lisible.
  ///
  /// In fr, this message translates to:
  /// **'Un groupe {app} propose un jumelage.'**
  String twinRequestTitleUnnamed(String app);

  /// Demande de jumelage : choisir le groupe Agora.
  ///
  /// In fr, this message translates to:
  /// **'Avec quel groupe Agora ?'**
  String get twinChooseGroup;

  /// Demande de jumelage : créer un groupe pour le jumeau.
  ///
  /// In fr, this message translates to:
  /// **'Un nouveau groupe'**
  String get twinNewGroup;

  /// Demande de jumelage : accepter.
  ///
  /// In fr, this message translates to:
  /// **'Jumeler'**
  String get twinConfirmButton;

  /// Réponse de l'autre app à un jumelage lancé ici.
  ///
  /// In fr, this message translates to:
  /// **'Relier « {group} » au groupe {app} choisi ?'**
  String twinResponseQuestion(String group, String app);

  /// Réponse de jumelage : enregistrer le jumeau.
  ///
  /// In fr, this message translates to:
  /// **'Relier'**
  String get twinLinkButton;

  /// Réponse de jumelage sans demande correspondante.
  ///
  /// In fr, this message translates to:
  /// **'Cette réponse ne correspond à aucun jumelage lancé depuis cet appareil. Relance le jumelage depuis le menu du groupe.'**
  String get twinResponseUnknown;

  /// Confirmation : jumeau enregistré.
  ///
  /// In fr, this message translates to:
  /// **'Jumelage enregistré.'**
  String get twinSaved;

  /// L'autre app n'a pas pu être ouverte.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ouvrir {app}. Le jumelage est enregistré ici ; relance-le depuis le menu du groupe pour finir.'**
  String twinOpenFailed(String app);

  /// Bandeau d'un groupe jumelé avec un cercle DewDrop : le code envoie une demande au créateur du cercle.
  ///
  /// In fr, this message translates to:
  /// **'Demander à rejoindre'**
  String get twinRequestJoinButton;

  /// Jumelage avec une app où rejoindre est une demande (DewDrop).
  ///
  /// In fr, this message translates to:
  /// **'Un jumeau est un groupe d\'une autre app. Ses membres y voient « Rejoindre aussi dans Agora », et ceux d\'ici « Demander à rejoindre dans {app} » : le créateur du cercle {app} accepte ou refuse chaque demande.'**
  String twinExplainRequest(String app);

  /// En tête de l'éditeur ouvert par un rdv préparé dans une autre app (lien #/event).
  ///
  /// In fr, this message translates to:
  /// **'Préparé dans {app} : vérifie le rdv avant de l\'enregistrer.'**
  String eventLinkFrom(String app);

  /// Rdv venu d'une autre app pour un groupe dont la personne n'est pas membre.
  ///
  /// In fr, this message translates to:
  /// **'Tu n\'es pas encore dans le groupe « {group} » : rejoins-le, puis rouvre le lien depuis {app} pour lui proposer le rdv.'**
  String eventLinkNotMember(String group, String app);

  /// Rdv venu d'une autre app : ouvrir l'adhésion au groupe jumeau.
  ///
  /// In fr, this message translates to:
  /// **'Rejoindre le groupe'**
  String get eventLinkJoinButton;

  /// Lien #/event illisible (date, durée, titre ou app inconnus).
  ///
  /// In fr, this message translates to:
  /// **'Ce lien de rdv n\'est pas valable. Rouvre-le depuis l\'app qui l\'a préparé.'**
  String get eventLinkInvalid;

  /// Éditeur de rdv : aide sous le choix d'agenda quand un agenda de groupe est choisi.
  ///
  /// In fr, this message translates to:
  /// **'Proposé au groupe : ses membres le voient et y répondent.'**
  String get eventProposedToGroup;

  /// Erreur : le groupe choisi a déjà un jumeau complet dans l'autre app.
  ///
  /// In fr, this message translates to:
  /// **'Ce groupe est déjà jumelé avec un autre groupe de cette app. Défais d\'abord ce jumelage depuis le menu du groupe.'**
  String get errorTwinExists;

  /// Titre de l'éditeur à la création de l'agenda d'un proche.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau proche'**
  String get newContactTitle;

  /// Champ du nom dans l'éditeur de l'agenda d'un proche.
  ///
  /// In fr, this message translates to:
  /// **'Nom du proche'**
  String get contactNameLabel;

  /// Éditeur d'un agenda de proche, à la place du réglage de partage.
  ///
  /// In fr, this message translates to:
  /// **'Visible de toi seul : ses repos et son anniversaire ne comptent jamais comme tes créneaux pris.'**
  String get contactCalendarHint;

  /// Mes agendas : en-tête des agendas tenus pour des proches.
  ///
  /// In fr, this message translates to:
  /// **'Proches'**
  String get contactCalendarsTitle;

  /// Mes agendas : créer l'agenda d'un proche.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un proche'**
  String get newContactButton;

  /// Mes agendas : précision sous « Ajouter un proche ».
  ///
  /// In fr, this message translates to:
  /// **'Ses repos, son anniversaire : pour toi seul'**
  String get newContactHint;

  /// Confirmation : agenda de proche créé.
  ///
  /// In fr, this message translates to:
  /// **'Proche ajouté.'**
  String get contactSaved;

  /// Mes agendas : sous-titre d'un agenda de proche (jamais partagé).
  ///
  /// In fr, this message translates to:
  /// **'Pour toi seul'**
  String get contactCalendarSubtitle;

  /// Import iCal : l'agenda importé est celui d'un proche.
  ///
  /// In fr, this message translates to:
  /// **'Le planning d\'un proche'**
  String get importForContactLabel;

  /// Import iCal : ce que change « Le planning d'un proche ».
  ///
  /// In fr, this message translates to:
  /// **'Visible de toi seul, jamais compté comme tes créneaux pris.'**
  String get importForContactHint;

  /// Onglet de l'accueil : proches et groupes.
  ///
  /// In fr, this message translates to:
  /// **'Social'**
  String get navSocial;

  /// Onglet de l'accueil : profil et réglages.
  ///
  /// In fr, this message translates to:
  /// **'Moi'**
  String get navMe;

  /// Social : bouton qui propose d'ajouter un proche, de créer ou de rejoindre un groupe.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get socialAddButton;

  /// Social : dates à retenir des proches dans les prochains jours.
  ///
  /// In fr, this message translates to:
  /// **'À venir'**
  String get upcomingTitle;

  /// Dans combien de jours tombe une date à retenir.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aujourd\'hui} =1{Demain} other{Dans {count} jours}}'**
  String daysAwayLabel(int count);

  /// Social : texte de la section Proches tant qu'il n'y en a aucun.
  ///
  /// In fr, this message translates to:
  /// **'Note les repos et l\'anniversaire de tes proches : tu es seul à les voir.'**
  String get contactsEmpty;

  /// Social : sous-titre d'un proche dont l'agenda est importé par lien iCal.
  ///
  /// In fr, this message translates to:
  /// **'Planning importé, pour toi seul'**
  String get contactImportedSubtitle;

  /// Page d'un proche : ce qui est noté maintenant.
  ///
  /// In fr, this message translates to:
  /// **'En ce moment'**
  String get contactNowTitle;

  /// Page d'un proche : rien n'est en cours.
  ///
  /// In fr, this message translates to:
  /// **'Rien de noté en ce moment.'**
  String get contactNothingNow;

  /// Page d'un proche : un rdv en cours et son heure de fin.
  ///
  /// In fr, this message translates to:
  /// **'{title}, jusqu\'à {time}'**
  String contactUntil(String title, String time);

  /// Page d'un proche : le prochain rdv noté et quand.
  ///
  /// In fr, this message translates to:
  /// **'Ensuite : {title}, {when}'**
  String contactNext(String title, String when);

  /// Page d'un proche : titre des raccourcis (anniversaire, horaires, repos, import).
  ///
  /// In fr, this message translates to:
  /// **'Ajouter vite'**
  String get contactShortcutsTitle;

  /// Raccourci : noter l'anniversaire d'un proche (journée entière, chaque année).
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire'**
  String get shortcutBirthday;

  /// Raccourci : noter les horaires de travail d'un proche (chaque semaine).
  ///
  /// In fr, this message translates to:
  /// **'Horaires de travail'**
  String get shortcutWorkHours;

  /// Raccourci : importer le planning d'un proche par son lien iCal.
  ///
  /// In fr, this message translates to:
  /// **'Importer son planning'**
  String get shortcutImport;

  /// Titre proposé par le raccourci Anniversaire.
  ///
  /// In fr, this message translates to:
  /// **'Anniversaire de {name}'**
  String birthdayEventTitle(String name);

  /// Titre proposé par le raccourci Horaires de travail.
  ///
  /// In fr, this message translates to:
  /// **'Travail'**
  String get workEventTitle;

  /// Raccourci de la page d'un proche : noter un congé (un jour ou une période) ; titre de son formulaire.
  ///
  /// In fr, this message translates to:
  /// **'Congé'**
  String get shortcutDayOff;

  /// Titre proposé par le raccourci Congé.
  ///
  /// In fr, this message translates to:
  /// **'Congé'**
  String get dayOffEventTitle;

  /// Page d'un proche : il a des horaires de travail, mais aucun aujourd'hui (ni congé).
  ///
  /// In fr, this message translates to:
  /// **'Repos aujourd\'hui.'**
  String get contactRestToday;

  /// Formulaire Anniversaire : sa date.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get contactFormDateLabel;

  /// Formulaire Congé : premier jour.
  ///
  /// In fr, this message translates to:
  /// **'Du'**
  String get dayOffFromLabel;

  /// Formulaire Congé : dernier jour, inclus.
  ///
  /// In fr, this message translates to:
  /// **'Au'**
  String get dayOffToLabel;

  /// Formulaire Horaires de travail : les jours cochés ; les autres sont ses repos.
  ///
  /// In fr, this message translates to:
  /// **'Jours travaillés'**
  String get workDaysLabel;

  /// Formulaire Horaires de travail : heure de début.
  ///
  /// In fr, this message translates to:
  /// **'De'**
  String get workFromLabel;

  /// Formulaire Horaires de travail : heure de fin.
  ///
  /// In fr, this message translates to:
  /// **'À'**
  String get workToLabel;

  /// Heure de fin d'un horaire de nuit, qui finit le jour suivant.
  ///
  /// In fr, this message translates to:
  /// **'{time} (le lendemain)'**
  String workEndsNextDay(String time);

  /// Formulaire Horaires de travail : premier jour de la série.
  ///
  /// In fr, this message translates to:
  /// **'À partir du'**
  String get workStartsOnLabel;

  /// Formulaire Horaires de travail : dernier jour de la série, s'il y en a un.
  ///
  /// In fr, this message translates to:
  /// **'Jusqu\'au'**
  String get workUntilLabel;

  /// Formulaire Horaires de travail : la série ne finit pas.
  ///
  /// In fr, this message translates to:
  /// **'Pas de date de fin'**
  String get workUntilNone;

  /// Formulaire Horaires de travail : début et fin à la même heure.
  ///
  /// In fr, this message translates to:
  /// **'L\'heure de fin doit différer de celle du début.'**
  String get validationWorkHours;

  /// Formulaire Horaires de travail : la date de fin précède le premier jour coché.
  ///
  /// In fr, this message translates to:
  /// **'La fin doit suivre le premier jour travaillé.'**
  String get validationWorkUntil;

  /// Page d'un proche : titre de la ligne qui le relie à un membre de ses groupes.
  ///
  /// In fr, this message translates to:
  /// **'Membre de tes groupes'**
  String get contactLinkTitle;

  /// Page d'un proche relié à un membre.
  ///
  /// In fr, this message translates to:
  /// **'Son nom suit son profil, et ce que ce membre partage dans tes groupes s\'affiche ici.'**
  String get contactLinkedHint;

  /// Page d'un proche qui n'est relié à aucun membre.
  ///
  /// In fr, this message translates to:
  /// **'Relie ce proche à un membre de tes groupes pour voir ce que ce membre y partage.'**
  String get contactNotLinkedHint;

  /// Bouton qui ouvre le choix du membre à relier au proche.
  ///
  /// In fr, this message translates to:
  /// **'Relier'**
  String get contactLinkButton;

  /// Bouton qui retire le lien entre le proche et le membre.
  ///
  /// In fr, this message translates to:
  /// **'Délier'**
  String get contactUnlinkButton;

  /// Titre de la liste des membres à relier au proche.
  ///
  /// In fr, this message translates to:
  /// **'Relier à un membre'**
  String get contactPickMemberTitle;

  /// Liste des membres à relier : vide (pas de groupe, ou tous déjà reliés).
  ///
  /// In fr, this message translates to:
  /// **'Aucun membre de tes groupes à relier.'**
  String get contactPickMemberEmpty;

  /// Confirmation : le proche est relié à un membre.
  ///
  /// In fr, this message translates to:
  /// **'Proche relié.'**
  String get contactLinkedSaved;

  /// Confirmation : le proche n'est plus relié à un membre.
  ///
  /// In fr, this message translates to:
  /// **'Lien retiré.'**
  String get contactUnlinkedSaved;

  /// Page d'un proche relié : ce que le membre partage dans les groupes communs.
  ///
  /// In fr, this message translates to:
  /// **'Dans tes groupes, 7 prochains jours'**
  String get contactSharedTitle;

  /// Page d'un proche relié : le membre ne partage rien sur la période.
  ///
  /// In fr, this message translates to:
  /// **'Rien de partagé ces 7 prochains jours.'**
  String get contactSharedEmpty;

  /// Éditeur d'un proche relié à un membre : le nom ne se change pas à la main.
  ///
  /// In fr, this message translates to:
  /// **'Son nom suit celui de son profil Agora.'**
  String get calendarNameFollowsProfile;

  /// Liste des membres : bouton qui crée le proche de ce membre.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à mes proches'**
  String get memberAddContact;

  /// Liste des membres : bouton qui ouvre la page du proche relié à ce membre.
  ///
  /// In fr, this message translates to:
  /// **'Voir sa page de proche'**
  String get memberOpenContact;

  /// Liste des membres : ce membre est relié à l'un de mes proches (fin de la ligne d'état).
  ///
  /// In fr, this message translates to:
  /// **'dans tes proches'**
  String get memberIsContact;

  /// Lien refusé : le membre ne partage plus aucun groupe.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne ne partage plus de groupe avec toi.'**
  String get errorNotCoMember;

  /// Lien refusé : le membre est déjà relié à un autre proche.
  ///
  /// In fr, this message translates to:
  /// **'Cette personne est déjà reliée à un autre de tes proches.'**
  String get errorContactAlreadyLinked;

  /// Nom proposé pour le planning importé d'un proche.
  ///
  /// In fr, this message translates to:
  /// **'Planning de {name}'**
  String contactImportedName(String name);

  /// Page d'un proche : titre de la liste de ses prochains rdv.
  ///
  /// In fr, this message translates to:
  /// **'Les 30 prochains jours'**
  String get contactUpcomingTitle;

  /// Page d'un proche : aucun rdv à venir.
  ///
  /// In fr, this message translates to:
  /// **'Rien de noté pour les 30 prochains jours.'**
  String get contactNothingUpcoming;

  /// Page d'un proche : noter un rdv dans son agenda.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get contactAddEventButton;

  /// Page d'un proche : renommer, changer la couleur, supprimer.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le proche'**
  String get contactEditTooltip;

  /// Éditeur de rdv : jours de la semaine d'une répétition hebdomadaire.
  ///
  /// In fr, this message translates to:
  /// **'Les jours'**
  String get repeatDaysLabel;

  /// Éditeur de rdv : une semaine sur combien.
  ///
  /// In fr, this message translates to:
  /// **'Rythme'**
  String get repeatIntervalLabel;

  /// Éditeur de rdv : rythme d'une répétition hebdomadaire.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Chaque semaine} other{Toutes les {count} semaines}}'**
  String repeatEveryWeeks(int count);

  /// Éditeur de rdv : date de la dernière occurrence.
  ///
  /// In fr, this message translates to:
  /// **'Fin de la répétition'**
  String get repeatEndLabel;

  /// Éditeur de rdv : la répétition ne s'arrête pas.
  ///
  /// In fr, this message translates to:
  /// **'Jamais'**
  String get repeatEndNever;

  /// Éditeur de rdv : la répétition s'arrête ce jour-là.
  ///
  /// In fr, this message translates to:
  /// **'Le {date}'**
  String repeatEndOn(String date);

  /// Éditeur de rdv : retirer la date de fin de la répétition.
  ///
  /// In fr, this message translates to:
  /// **'Sans fin'**
  String get repeatEndClearTooltip;

  /// Onglet Moi : titre de la section des réglages (langue, fuseau, agendas).
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get meSettingsTitle;

  /// Onglet Moi : titre de la section Google, Discord et assistant IA.
  ///
  /// In fr, this message translates to:
  /// **'Connexions'**
  String get meConnectionsTitle;

  /// Onglet Moi : titre de la section déconnexion et pages légales.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get meAccountTitle;

  /// Onglet Moi : bouton qui ouvre la saisie du nom affiché.
  ///
  /// In fr, this message translates to:
  /// **'Changer ton nom'**
  String get editNameTooltip;

  /// Onglet Moi : le fuseau du profil est celui du téléphone.
  ///
  /// In fr, this message translates to:
  /// **'{zone}, celui de cet appareil'**
  String timezoneMatchesDevice(String zone);

  /// Onglet Moi : sous-titre de la ligne « Mes agendas ».
  ///
  /// In fr, this message translates to:
  /// **'Créer, importer, couleurs et partage'**
  String get calendarsTileSubtitle;

  /// Écran Assistant IA : section repliable qui explique comment brancher un assistant.
  ///
  /// In fr, this message translates to:
  /// **'Brancher un assistant'**
  String get assistantConnectTitle;

  /// Vue d'agenda : trois jours glissants (la « semaine » d'un téléphone).
  ///
  /// In fr, this message translates to:
  /// **'3 jours'**
  String get viewThreeDays;

  /// Agenda : bouton qui choisit la vue (jour, 3 jours, mois, planning).
  ///
  /// In fr, this message translates to:
  /// **'Changer de vue'**
  String get viewMenuTooltip;

  /// Agenda : bouton qui choisit les agendas montrés dans sa vue.
  ///
  /// In fr, this message translates to:
  /// **'Agendas affichés'**
  String get shownCalendarsTooltip;

  /// Titre du choix des agendas montrés dans sa vue.
  ///
  /// In fr, this message translates to:
  /// **'Afficher dans mon agenda'**
  String get shownCalendarsTitle;

  /// Précision du choix des agendas montrés : c'est de l'affichage, pas du partage.
  ///
  /// In fr, this message translates to:
  /// **'Masquer un agenda ne change rien pour tes groupes.'**
  String get shownCalendarsHint;

  /// Fiche d'un rdv : ouvrir l'éditeur.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get eventEditButton;

  /// Vue mois d'un téléphone : le jour touché n'a aucun rdv.
  ///
  /// In fr, this message translates to:
  /// **'Rien de noté ce jour-là.'**
  String get dayEmpty;

  /// Page d'un groupe : ce que je partage avec lui ; un appui le change.
  ///
  /// In fr, this message translates to:
  /// **'Je partage : {level}'**
  String groupMyShareChip(String level);

  /// Social : sous-titre d'un groupe, son prochain rdv.
  ///
  /// In fr, this message translates to:
  /// **'Prochain : {title}, {when}'**
  String groupNextEvent(String title, String when);

  /// Invitation : ouvrir la feuille de partage du téléphone.
  ///
  /// In fr, this message translates to:
  /// **'Partager'**
  String get shareInviteButton;

  /// Texte partagé avec le lien d'invitation.
  ///
  /// In fr, this message translates to:
  /// **'Rejoins « {group} » sur Agora : {link}'**
  String inviteShareLink(String group, String link);

  /// Texte partagé avec le code d'invitation (sans adresse web).
  ///
  /// In fr, this message translates to:
  /// **'Rejoins « {group} » sur Agora avec le code {code}'**
  String inviteShareCode(String group, String code);

  /// Rejoindre un groupe : coller le code ou le lien reçu.
  ///
  /// In fr, this message translates to:
  /// **'Coller'**
  String get pasteTooltip;

  /// Puce de la page d'un groupe : je partage tout (titres et lieux).
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get shareShortDetails;

  /// Puce de la page d'un groupe : je partage « occupé », sans détail.
  ///
  /// In fr, this message translates to:
  /// **'Occupé'**
  String get shareShortBusy;

  /// Puce de la page d'un groupe : je ne partage rien.
  ///
  /// In fr, this message translates to:
  /// **'Rien'**
  String get shareShortNothing;
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
