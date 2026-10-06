/// Les proches dans l'onglet Social : leurs dates à retenir des prochains
/// jours (« À venir »), puis la liste des proches, qui ouvre leur page.
///
/// Choix non évidents :
/// - « À venir » disparaît quand il n'y a rien : une section vide ne dit
///   rien d'utile ;
/// - ajouter un proche mène tout de suite à sa page, où l'attendent les
///   raccourcis : un agenda vide n'a pas d'autre suite.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/common_widgets/section_title.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/application/contact_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/calendars_actions.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Crée l'agenda d'un proche, puis ouvre sa page.
Future<void> addContact(BuildContext context, WidgetRef ref) async {
  final id = await createCalendar(context, ref, contact: true);
  if (id == null || !context.mounted) return;
  await openContact(context, id);
}

/// Ouvre la page du proche [calendarId].
Future<void> openContact(BuildContext context, String calendarId) =>
    context.pushNamed(
      AppRoute.contact.name,
      pathParameters: {'calendarId': calendarId},
    );

/// Les dates à retenir des proches ; rien du tout s'il n'y en a pas.
class UpcomingAnniversaries extends ConsumerWidget {
  const UpcomingAnniversaries({required this.sectionKey, super.key});

  /// Clé de la section, posée par l'écran qui l'accueille.
  final Key sectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.MMMEd(locale);
    final anniversaries =
        ref.watch(upcomingAnniversariesProvider).value ?? const [];
    if (anniversaries.isEmpty) return const SizedBox.shrink();
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.upcomingTitle),
        for (final anniversary in anniversaries)
          ListTile(
            key: CalendarKeys.anniversaryTile(anniversary.item.instanceKey),
            leading: const Icon(Icons.cake_outlined),
            title: Text(anniversary.item.title),
            subtitle: Text(
              '${l10n.daysAwayLabel(anniversary.daysAway)} · '
              '${date.format(anniversary.item.localStart)}',
            ),
            onTap: () => openContact(context, anniversary.item.calendarId),
          ),
      ],
    );
  }
}

/// La liste des proches.
class ContactsSection extends ConsumerWidget {
  const ContactsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contacts = [
      for (final calendar
          in ref.watch(calendarsProvider).value ?? const <UserCalendar>[])
        if (calendar.isContact) calendar,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(l10n.contactCalendarsTitle),
        if (contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.contactsEmpty),
          ),
        for (final calendar in contacts)
          _ContactTile(
            calendar: calendar,
            onTap: () => openContact(context, calendar.id),
          ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.calendar, required this.onTap});

  final UserCalendar calendar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = colorFromHex(
      calendar.colorHex,
      Theme.of(context).colorScheme.primary,
    );
    return ListTile(
      key: CalendarKeys.contactTile(calendar.id),
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          calendar.name.characters.firstOrNull?.toUpperCase() ?? '',
          style: TextStyle(color: readableOn(color)),
        ),
      ),
      title: Text(calendar.name),
      subtitle: Text(
        calendar.isImported
            ? l10n.contactImportedSubtitle
            : l10n.contactCalendarSubtitle,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
