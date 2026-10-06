/// Ce que la page d'un proche montre de son lien avec un membre de mes
/// groupes : la ligne qui le relie (ou le délie), et ce que ce membre
/// partage dans les groupes que j'ai en commun avec lui.
///
/// Choix non évidents :
/// - on ne propose que des co-membres (`coMembersProvider`), et pas ceux
///   déjà reliés à un autre de mes proches : le serveur le refuserait ;
/// - le partage vient de `group_agenda()`, groupe par groupe
///   (`memberAgendaProvider`) : on n'y voit rien de plus qu'en ouvrant ces
///   groupes, et la règle de vie privée reste en base. Sept jours suffisent
///   à dire s'il est pris cette semaine, sans noyer la page ;
/// - relié, le proche prend le nom du membre (en base) : il le suit tant
///   qu'ils partagent un groupe, et garde le dernier une fois délié.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/event_actions.dart';
import 'package:agora/src/features/calendar/presentation/event_when_label.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Jours de partage montrés sur la page d'un proche relié.
const _sharedDays = 7;

/// La ligne « Membre de tes groupes » : relier le proche à un membre, ou
/// le délier.
class ContactMemberLink extends ConsumerWidget {
  const ContactMemberLink({required this.calendar, super.key});

  final UserCalendar calendar;

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final userId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MemberPicker(calendarId: calendar.id),
    );
    if (userId == null || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(calendarsServiceProvider).linkContact(calendar.id, userId),
      AppLocalizations.of(context).contactLinkedSaved,
    );
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) => runAction(
    context,
    () => ref.read(calendarsServiceProvider).linkContact(calendar.id, null),
    AppLocalizations.of(context).contactUnlinkedSaved,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isLinked = calendar.isLinkedToMember;
    return ListTile(
      leading: const Icon(Icons.groups_outlined),
      title: Text(l10n.contactLinkTitle),
      subtitle: Text(
        isLinked ? l10n.contactLinkedHint : l10n.contactNotLinkedHint,
      ),
      trailing: isLinked
          ? TextButton(
              key: CalendarKeys.contactUnlink,
              onPressed: () => _unlink(context, ref),
              child: Text(l10n.contactUnlinkButton),
            )
          : FilledButton.tonal(
              key: CalendarKeys.contactLink,
              onPressed: () => _link(context, ref),
              child: Text(l10n.contactLinkButton),
            ),
    );
  }
}

/// Les membres de mes groupes qu'on peut relier à ce proche.
class _MemberPicker extends ConsumerWidget {
  const _MemberPicker({required this.calendarId});

  final String calendarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final taken = {
      for (final calendar
          in ref.watch(calendarsProvider).value ?? const <UserCalendar>[])
        if (calendar.id != calendarId) ?calendar.contactUserId,
    };
    final members = [
      for (final member
          in ref.watch(coMembersProvider).value ?? const <GroupMember>[])
        if (!taken.contains(member.userId)) member,
    ];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              l10n.contactPickMemberTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (ref.watch(coMembersProvider) case AsyncError(:final error))
            ListTile(title: Text(messageForError(error, l10n)))
          else if (ref.watch(coMembersProvider).isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (members.isEmpty)
            ListTile(title: Text(l10n.contactPickMemberEmpty)),
          for (final member in members)
            ListTile(
              key: CalendarKeys.contactLinkOption(member.userId),
              leading: const Icon(Icons.person_outline),
              title: Text(member.displayName),
              onTap: () => Navigator.of(context).pop(member.userId),
            ),
        ],
      ),
    );
  }
}

/// Ce que le membre relié partage dans mes groupes, les [_sharedDays]
/// prochains jours.
class ContactSharedAgenda extends ConsumerWidget {
  const ContactSharedAgenda({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final slots = ref.watch(
      memberAgendaProvider(
        MemberAgendaQuery(
          userId: userId,
          from: DateTime(now.year, now.month, now.day).toUtc(),
          to: DateTime(now.year, now.month, now.day + _sharedDays).toUtc(),
        ),
      ),
    );
    final list = slots.value ?? const <GroupAgendaItem>[];
    return Column(
      key: CalendarKeys.contactShared,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            l10n.contactSharedTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (slots.isLoading && !slots.hasValue)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.contactSharedEmpty),
          ),
        for (final slot in list)
          ListTile(
            leading: Icon(
              slot.level == ShareLevel.details
                  ? Icons.event_outlined
                  : Icons.block_outlined,
            ),
            title: Text(slot.title ?? l10n.busyLabel),
            subtitle: Text(
              slotWhenLabel(
                localStart: slot.localStart,
                localEnd: slot.localEnd,
                isAllDay: slot.isAllDay,
                locale: locale,
              ),
            ),
          ),
      ],
    );
  }
}
