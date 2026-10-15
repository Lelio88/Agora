/// Les phrases qui décrivent un lien de profil : ce qu'il laisse voir, et de
/// quels agendas. Partagées par la liste et la fenêtre d'un lien.
library;

import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/localization/app_localizations.dart';

String levelLine(ProfileLinkLevel level, AppLocalizations l10n) =>
    level == ProfileLinkLevel.details
    ? l10n.profileLinkSeesDetails
    : l10n.profileLinkSeesBusy;

/// Les agendas du lien : « Tous tes agendas » pour un lien d'avant le choix,
/// sinon les noms de ceux qui existent encore (un agenda supprimé ne rend pas
/// le lien plus large : s'il n'en reste aucun, il ne partage plus rien).
String calendarsLine(
  ProfileLink link,
  List<ShareableCalendar> mine,
  AppLocalizations l10n,
) {
  final ids = link.calendarIds;
  if (ids == null) return l10n.profileLinkAllCalendars;
  final names = [
    for (final calendar in mine)
      if (ids.contains(calendar.id)) calendar.name,
  ];
  return names.isEmpty
      ? l10n.profileLinkNoCalendarLeft
      : l10n.profileLinkCalendarsLine(names.join(', '));
}
