// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Agora';

  @override
  String get homeTagline => 'Your calendars, together.';

  @override
  String homeGreeting(String name) {
    return 'Hi, $name!';
  }

  @override
  String get profileTooltip => 'Profile';

  @override
  String get emailLabel => 'Email address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHelper =>
      'At least 8 characters, with letters and numbers.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameHelper => 'Shown to the members of your groups.';

  @override
  String get codeLabel => '6-digit code';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInButton => 'Sign in';

  @override
  String get forgotPasswordLink => 'Forgot your password?';

  @override
  String get noAccountPrompt => 'No account yet?';

  @override
  String get createAccountLink => 'Create an account';

  @override
  String get confirmEmailAction => 'Get a confirmation code';

  @override
  String get signUpTitle => 'Create an account';

  @override
  String get signUpButton => 'Create my account';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String get verifyEmailTitle => 'Check your inbox';

  @override
  String verifyEmailInstructions(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get verifyButton => 'Confirm';

  @override
  String get resendCodeButton => 'Resend the code';

  @override
  String get codeResent => 'New code sent.';

  @override
  String get forgotPasswordTitle => 'Forgot password';

  @override
  String get forgotPasswordInstructions =>
      'Enter your email: if an account uses it, you will receive a code to choose a new password.';

  @override
  String get sendCodeButton => 'Send me a code';

  @override
  String get resetPasswordTitle => 'New password';

  @override
  String resetPasswordInstructions(String email) {
    return 'Enter the code sent to $email and choose a new password.';
  }

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetPasswordButton => 'Change password';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileLanguageLabel => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get profileTimezoneLabel => 'Time zone';

  @override
  String get useDeviceTimezone => 'Use this device\'s';

  @override
  String get saveButton => 'Save';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get signOutButton => 'Sign out';

  @override
  String get validationEmail => 'Invalid email address.';

  @override
  String get validationPasswordTooShort => 'At least 8 characters.';

  @override
  String get validationPasswordLettersDigits => 'Use both letters and numbers.';

  @override
  String get validationCode => 'The code has 6 digits.';

  @override
  String get validationDisplayName => 'Between 1 and 60 characters.';

  @override
  String get errorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get errorEmailNotConfirmed =>
      'Confirm your email first with the code we sent you.';

  @override
  String get errorEmailAlreadyRegistered =>
      'An account already uses this email. Sign in, or use “Forgot your password?”.';

  @override
  String get errorInvalidCode => 'Incorrect or expired code.';

  @override
  String get errorWeakPassword =>
      'Password too weak: at least 8 characters, with letters and numbers.';

  @override
  String get errorInvalidEmail => 'Invalid email address.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Try again in a few minutes.';

  @override
  String get errorInvalidTimezone => 'Unknown time zone.';

  @override
  String get errorNetwork => 'Can\'t reach the server. Check your connection.';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get deleteAccountButton => 'Delete my account';

  @override
  String get deleteAccountTitle => 'Delete your account?';

  @override
  String get deleteAccountBody =>
      'Your profile, calendars and events will be permanently erased. Groups you own go to another member; groups where you are alone are deleted. This cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Delete permanently';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get accountDeleted => 'Your account has been deleted.';

  @override
  String get agendaTitle => 'Agenda';

  @override
  String get viewDay => 'Day';

  @override
  String get viewWeek => 'Week';

  @override
  String get viewMonth => 'Month';

  @override
  String get viewSchedule => 'Schedule';

  @override
  String get todayButton => 'Today';

  @override
  String get previousPeriod => 'Previous period';

  @override
  String get nextPeriod => 'Next period';

  @override
  String get newEventTooltip => 'New event';

  @override
  String get newEventTitle => 'New event';

  @override
  String get editEventTitle => 'Edit event';

  @override
  String get eventTitleLabel => 'Title';

  @override
  String get eventLocationLabel => 'Location';

  @override
  String get eventDescriptionLabel => 'Notes';

  @override
  String get allDayLabel => 'All day';

  @override
  String get startsLabel => 'Starts';

  @override
  String get endsLabel => 'Ends';

  @override
  String get repeatLabel => 'Repeat';

  @override
  String get repeatNever => 'Never';

  @override
  String get repeatDaily => 'Every day';

  @override
  String get repeatWeekly => 'Every week';

  @override
  String get repeatMonthly => 'Every month';

  @override
  String get repeatYearly => 'Every year';

  @override
  String get repeatAdvanced => 'Advanced rule (imported)';

  @override
  String get visibilityLabel => 'For the members of my groups';

  @override
  String get visibilityInherit => 'As the group allows';

  @override
  String get visibilityBusy => 'Busy, no details';

  @override
  String get visibilityInvisible => 'Invisible';

  @override
  String get deleteEventButton => 'Delete';

  @override
  String get validationTitle => 'Between 1 and 200 characters.';

  @override
  String get validationEndBeforeStart => 'The end must come after the start.';

  @override
  String get eventSaved => 'Event saved.';

  @override
  String get eventDeleted => 'Event deleted.';

  @override
  String get scopeTitle => 'Repeating event';

  @override
  String get scopeEditBody => 'Edit only this occurrence, or the whole series?';

  @override
  String get scopeDeleteBody =>
      'Delete only this occurrence, or the whole series?';

  @override
  String get scopeThisOccurrence => 'This occurrence';

  @override
  String get scopeWholeSeries => 'Whole series';

  @override
  String get noEventsInRange => 'No events in this period.';

  @override
  String get errorEventNotFound => 'This event no longer exists.';

  @override
  String get errorLastCalendar =>
      'Keep at least one calendar: that is where your new events go.';

  @override
  String get errorCalendarNotFound => 'This calendar no longer exists.';

  @override
  String get calendarsTitle => 'My calendars';

  @override
  String get manageCalendarsTooltip => 'My calendars';

  @override
  String get newCalendarButton => 'New calendar';

  @override
  String get newCalendarTitle => 'New calendar';

  @override
  String get editCalendarTitle => 'Edit calendar';

  @override
  String get calendarNameLabel => 'Name';

  @override
  String get calendarColorLabel => 'Color';

  @override
  String get calendarShownTooltip => 'Show in my agenda';

  @override
  String calendarVisibilitySummary(String level) {
    return 'Groups: $level';
  }

  @override
  String get validationCalendarName => 'Between 1 and 60 characters.';

  @override
  String get calendarSaved => 'Calendar saved.';

  @override
  String get deleteCalendarButton => 'Delete calendar';

  @override
  String deleteCalendarTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String deleteCalendarBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Its $count events will be deleted with it, permanently.',
      one: 'Its event will be deleted with it, permanently.',
      zero: 'It has no events.',
    );
    return '$_temp0';
  }

  @override
  String get calendarDeleted => 'Calendar deleted.';

  @override
  String get lastCalendarHint => 'Your only calendar cannot be deleted.';

  @override
  String get eventCalendarLabel => 'Calendar';

  @override
  String get scopeMoveBody => 'Move only this occurrence, or the whole series?';

  @override
  String get scopeCalendarMoveNote =>
      'Changing the calendar always applies to the whole series.';

  @override
  String get eventMoved => 'Event moved.';
}
