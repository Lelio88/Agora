/// Fiche d'un rdv de groupe : ce qu'il est, qui l'a proposé, ma réponse
/// (présent / peut-être / absent) et celles des autres membres. Le créateur
/// et les admins du groupe peuvent le modifier ou le supprimer.
///
/// Ouverte par la route `/groups/:groupId/events/:eventId?start=…`, depuis
/// l'agenda du groupe comme depuis l'agenda perso ; `start` désigne
/// l'occurrence d'une série. Rend `true` si le rdv a été modifié ou
/// supprimé.
///
/// Choix non évidents :
/// - les membres (noms, rôle, « moi ») viennent de la feature groupes, par
///   son application : la fiche ne connaît pas leur dépôt ;
/// - un membre sans réponse est listé à part : savoir qui n'a pas répondu
///   sert autant que savoir qui vient ;
/// - le serveur revérifie tout (appartenance, droit de modifier) ; les
///   boutons ne font que ne pas proposer l'impossible.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/features/calendar/application/calendar_service.dart';
import 'package:agora/src/features/calendar/application/calendars_providers.dart';
import 'package:agora/src/features/calendar/application/group_event_providers.dart';
import 'package:agora/src/features/calendar/domain/agenda_item.dart';
import 'package:agora/src/features/calendar/domain/calendar_repository.dart';
import 'package:agora/src/features/calendar/domain/event_response.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:agora/src/features/calendar/presentation/event_actions.dart';
import 'package:agora/src/features/calendar/presentation/event_when_label.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupEventScreen extends ConsumerWidget {
  const GroupEventScreen({
    required this.groupId,
    required this.eventId,
    this.start,
    super.key,
  });

  final String groupId;
  final String eventId;

  /// Début de l'instance ; désigne l'occurrence d'une série.
  final DateTime? start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final instance = ref.watch(
      groupEventProvider(GroupEventQuery(eventId, start: start)),
    );
    final group = ref.watch(myGroupProvider(groupId)).value;
    final members = ref.watch(groupMembersProvider(groupId)).value ?? const [];
    final found = instance.value;
    final canEdit = found != null && _canEdit(found, group, members);
    return Scaffold(
      key: CalendarKeys.groupEventScreen,
      appBar: AppBar(
        title: Text(group?.name ?? ''),
        actions: [
          if (canEdit) ...[
            IconButton(
              key: CalendarKeys.groupEventEdit,
              tooltip: l10n.editEventTitle,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, ref, found.item),
            ),
            IconButton(
              key: CalendarKeys.groupEventDelete,
              tooltip: l10n.deleteEventButton,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, found.item),
            ),
          ],
        ],
      ),
      body: AsyncValueWidget<GroupEventInstance?>(
        value: instance,
        data: (found) => found == null
            ? Center(child: Text(l10n.errorEventNotFound))
            : _Details(instance: found, members: members),
      ),
    );
  }

  /// Le créateur, ou un admin (propriétaire compris) du groupe.
  static bool _canEdit(
    GroupEventInstance instance,
    MyGroup? group,
    List<GroupMember> members,
  ) {
    final me = members.where((m) => m.isMe).firstOrNull;
    return (me != null && me.userId == instance.createdBy) ||
        group?.role == GroupRole.owner ||
        group?.role == GroupRole.admin;
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AgendaItem item,
  ) async {
    final calendars = [
      ...?ref
          .read(calendarsProvider)
          .value
          ?.where((calendar) => calendar.id == item.calendarId),
    ];
    final changed = await editInstance(
      context,
      ref,
      item,
      calendars: calendars,
    );
    if (changed && context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AgendaItem item,
  ) async {
    final deleted = await deleteInstance(context, ref, item);
    if (deleted && context.mounted) Navigator.of(context).pop(true);
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.instance, required this.members});

  final GroupEventInstance instance;
  final List<GroupMember> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final item = instance.item;
    final responses =
        ref.watch(eventResponsesProvider(item.responseKey)).value ?? const [];
    final byUser = {for (final r in responses) r.userId: r.status};
    final me = members.where((m) => m.isMe).firstOrNull;
    String nameOf(GroupMember member) =>
        member.isMe ? l10n.memberYou : member.displayName;
    final creator = members
        .where((m) => m.userId == instance.createdBy)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(item.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _Line(
          icon: Icons.schedule,
          text: eventWhenLabel(
            item,
            Localizations.localeOf(context).toString(),
          ),
        ),
        if (item.location case final location?)
          _Line(icon: Icons.place_outlined, text: location),
        if (creator != null)
          _Line(
            icon: Icons.person_outline,
            text: creator.isMe
                ? l10n.proposedByMe
                : l10n.proposedBy(creator.displayName),
          ),
        if (item.description case final description?) ...[
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
        const Divider(height: 32),
        Text(l10n.myResponseLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ResponseStatus>(
          key: CalendarKeys.myResponse,
          segments: [
            for (final status in ResponseStatus.values)
              ButtonSegment(
                value: status,
                label: Text(
                  responseLabel(status, l10n),
                  key: CalendarKeys.responseOption(status),
                ),
              ),
          ],
          selected: {?byUser[me?.userId]},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (selection) => runAction(
            context,
            () => ref
                .read(calendarServiceProvider)
                .respond(item, selection.firstOrNull),
            selection.isEmpty ? l10n.responseRemoved : l10n.responseSaved,
          ),
        ),
        if (item.kind == InstanceKind.seriesOccurrence) ...[
          const SizedBox(height: 4),
          Text(l10n.occurrenceResponseNote, style: theme.textTheme.bodySmall),
        ],
        const Divider(height: 32),
        Text(l10n.responsesTitle, style: theme.textTheme.titleMedium),
        for (final status in ResponseStatus.values)
          _ResponseGroup(
            key: CalendarKeys.responseSection(status),
            label: responseLabel(status, l10n),
            names: [
              for (final member in members)
                if (byUser[member.userId] == status) nameOf(member),
            ],
          ),
        _ResponseGroup(
          key: CalendarKeys.noResponseSection,
          label: l10n.responseNone,
          names: [
            for (final member in members)
              if (!byUser.containsKey(member.userId)) nameOf(member),
          ],
        ),
      ],
    );
  }
}

/// Libellé d'une réponse.
String responseLabel(ResponseStatus status, AppLocalizations l10n) =>
    switch (status) {
      ResponseStatus.yes => l10n.responseYes,
      ResponseStatus.maybe => l10n.responseMaybe,
      ResponseStatus.no => l10n.responseNo,
    };

class _ResponseGroup extends StatelessWidget {
  const _ResponseGroup({required this.label, required this.names, super.key});

  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      AppLocalizations.of(context).responseSectionTitle(label, names.length),
    ),
    subtitle: names.isEmpty ? null : Text(names.join(', ')),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
