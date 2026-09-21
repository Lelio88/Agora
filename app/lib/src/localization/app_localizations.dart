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
