/// Agenda d'un groupe : les créneaux de tous les membres dans la même
/// grille, une couleur par membre, des pastilles pour en masquer, et les
/// rdv du groupe. Depuis la barre : inviter, les membres, et le menu du
/// groupe (renommer, quitter, supprimer). « Proposer un rdv » (ou un appui
/// sur un créneau libre) crée un rdv du groupe ; un appui sur un rdv du
/// groupe ouvre sa fiche (réponses).
///
/// Choix non évidents :
/// - les créneaux viennent de `group_agenda`, déjà passés par la règle de
///   vie privée : un créneau « occupé » n'a ni titre ni lieu, et un membre
///   qui ne partage rien n'a aucun créneau. L'écran n'a rien à cacher ;
/// - les tuiles sont en lecture seule : on modifie ses rdv depuis son agenda ;
/// - proposer un rdv et sa fiche sont des écrans de la feature agenda,
///   ouverts par leur nom de route : cette feature ne les connaît pas. Au
///   retour, l'agenda du groupe se relit (il n'est pas en temps réel) ;
/// - masquer un membre est un filtre local à l'écran, sans effet ailleurs.
library;

import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/group_agenda_item.dart';
import 'package:agora/src/features/groups/presentation/group_editor_screen.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/group_labels.dart';
import 'package:agora/src/features/groups/presentation/group_members_screen.dart';
import 'package:agora/src/features/groups/presentation/invite_sheet.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kalender/kalender.dart';

enum _MenuAction { rename, leave, delete }

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  final _eventsController = DefaultEventsController();
  final _kalenderController = KalenderController();
  late final VisibleRangeFollower _follower;
  late LoadedRange _range;
  AgendaView _view = AgendaView.week;

  /// Membres masqués dans cette vue.
  final _hidden = <String>{};

  @override
  void initState() {
    super.initState();
    _follower = VisibleRangeFollower(
      _kalenderController,
      initialDate: DateTime.now(),
      onRangeChanged: (range) {
        if (mounted) setState(() => _range = range);
      },
    );
    _range = _follower.range;
  }

  @override
  void dispose() {
    _follower.dispose();
    _kalenderController.dispose();
    _eventsController.dispose();
    super.dispose();
  }

  GroupAgendaQuery get _query => GroupAgendaQuery(
    groupId: widget.groupId,
    from: _range.from,
    to: _range.to,
  );

  List<GroupAgendaItem>? _syncedItems;
  List<GroupMember>? _syncedMembers;
  Set<String>? _syncedHidden;

  /// Pousse les créneaux visibles dans kalender, seulement s'ils ont changé.
  void _syncEvents(List<GroupAgendaItem> items, List<GroupMember> members) {
    if (identical(items, _syncedItems) &&
        identical(members, _syncedMembers) &&
        _syncedHidden != null &&
        _syncedHidden!.containsAll(_hidden) &&
        _hidden.containsAll(_syncedHidden!)) {
      return;
    }
    _syncedItems = items;
    _syncedMembers = members;
    _syncedHidden = {..._hidden};
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final rank = {
      for (final (index, member) in members.indexed) member.userId: index,
    };
    final names = {
      for (final member in members)
        member.userId: member.isMe ? l10n.memberYou : member.displayName,
    };
    _eventsController.replaceEvents([
      for (final item in items)
        if (item.userId == null || !_hidden.contains(item.userId))
          _GroupEvent(
            item,
            color: item.userId == null
                ? colors.secondaryContainer
                : memberColor(rank[item.userId] ?? 0, colors),
            owner: item.userId == null
                ? l10n.groupEventOwner
                : names[item.userId] ?? '',
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final group = ref.watch(myGroupProvider(widget.groupId));
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final agenda = ref.watch(groupAgendaProvider(_query));
    if ((agenda.value, members.value) case (final items?, final list?)) {
      _syncEvents(items, list);
    }
    final myGroup = group.value;
    return Scaffold(
      key: GroupKeys.groupScreen,
      floatingActionButton: FloatingActionButton.extended(
        key: GroupKeys.proposeEvent,
        // L'accueil, dessous, a ses propres boutons : chacun son tag.
        heroTag: GroupKeys.proposeEvent,
        icon: const Icon(Icons.add),
        label: Text(l10n.proposeEventButton),
        onPressed: _proposeEvent,
      ),
      appBar: AppBar(
        title: Text(myGroup?.name ?? ''),
        actions: [
          if (myGroup != null) ...[
            IconButton(
              key: GroupKeys.invite,
              tooltip: l10n.inviteTooltip,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              onPressed: () => showInviteSheet(context, myGroup),
            ),
            IconButton(
              key: GroupKeys.members,
              tooltip: l10n.groupMembersTooltip,
              icon: const Icon(Icons.group_outlined),
              onPressed: () => GroupMembersScreen.show(context, myGroup.id),
            ),
            _GroupMenu(group: myGroup, onSelected: _onMenu),
          ],
        ],
      ),
      body: AsyncValueWidget<List<GroupMember>>(
        value: members,
        data: (list) => Column(
          children: [
            _MemberChips(
              members: list,
              hidden: _hidden,
              onToggle: (userId) => setState(() {
                if (!_hidden.remove(userId)) _hidden.add(userId);
              }),
            ),
            AgendaToolbar(
              keys: GroupKeys.toolbar,
              view: _view,
              onViewChanged: (view) => setState(() => _view = view),
              controller: _kalenderController,
              trailing: [
                IconButton(
                  key: GroupKeys.refresh,
                  tooltip: MaterialLocalizations.of(context)
                      .refreshIndicatorSemanticLabel,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(groupAgendaProvider(_query)),
                ),
              ],
            ),
            Expanded(
              child: AsyncValueWidget<List<GroupAgendaItem>>(
                value: agenda,
                data: (_) => KalenderView(
                  eventsController: _eventsController,
                  kalenderController: _kalenderController,
                  viewConfiguration: agendaViewConfiguration(context, _view),
                  locale: Localizations.localeOf(context),
                  callbacks: KalenderCallbacks(
                    onEventTapped: (event) {
                      if (event is! _GroupEvent) return;
                      final item = event.item;
                      if (item.isGroupEvent && item.eventId != null) {
                        _openGroupEvent(item);
                      } else {
                        _showDetails(event);
                      }
                    },
                    onTapped: _proposeEvent,
                  ),
                  header: KalenderHeader(
                    multiDayTileComponents: _tileComponents,
                    interaction: _readOnly,
                  ),
                  body: KalenderBody(
                    multiDayTileComponents: _tileComponents,
                    monthTileComponents: _tileComponents,
                    scheduleTileComponents: const ScheduleTileComponents(
                      tileBuilder: _buildTile,
                    ),
                    interaction: _readOnly,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Propose un rdv au groupe, au créneau touché s'il y en a un.
  Future<void> _proposeEvent([DateTime? start]) async {
    await context.pushNamed<bool>(
      AppRoute.groupEventNew.name,
      pathParameters: {'groupId': widget.groupId},
      queryParameters: {
        if (start != null) 'start': start.toUtc().toIso8601String(),
      },
    );
    if (mounted) ref.invalidate(groupAgendaProvider);
  }

  /// Ouvre la fiche d'un rdv du groupe ; au retour, relit l'agenda (le rdv
  /// a pu être modifié ou supprimé).
  Future<void> _openGroupEvent(GroupAgendaItem item) async {
    await context.pushNamed<bool>(
      AppRoute.groupEvent.name,
      pathParameters: {'groupId': widget.groupId, 'eventId': item.eventId!},
      queryParameters: {'start': item.start.toUtc().toIso8601String()},
    );
    if (mounted) ref.invalidate(groupAgendaProvider);
  }

  void _showDetails(_GroupEvent event) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final item = event.item;
    final date = DateFormat.yMMMEd(locale);
    final time = DateFormat.Hm(locale);
    final when = item.isAllDay
        ? date.format(item.localStart)
        : '${date.format(item.localStart)} · '
              '${time.format(item.localStart)}–${time.format(item.localEnd)}';
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: event.color, radius: 10),
        title: Text(item.title ?? l10n.busyLabel),
        subtitle: Text([event.owner, when, ?item.location].join('\n')),
      ),
    );
  }

  Future<void> _onMenu(_MenuAction action, MyGroup group) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(groupsServiceProvider);
    switch (action) {
      case _MenuAction.rename:
        final draft = await GroupEditorScreen.show(
          context,
          initialName: group.name,
        );
        if (draft == null || !mounted) return;
        await _run(
          () => service.rename(group.id, name: draft.name),
          l10n.groupSaved,
        );
      case _MenuAction.leave:
        if (group.role == GroupRole.owner) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.ownerMustTransfer)));
          return;
        }
        final confirmed = await confirmAction(
          context,
          title: l10n.leaveGroupTitle(group.name),
          body: l10n.leaveGroupBody,
          action: l10n.leaveGroup,
        );
        if (!confirmed || !mounted) return;
        if (await _run(() => service.leave(group.id), l10n.leftGroup)) {
          _close();
        }
      case _MenuAction.delete:
        final confirmed = await confirmAction(
          context,
          title: l10n.deleteGroupTitle(group.name),
          body: l10n.deleteGroupBody,
          action: l10n.deleteGroup,
        );
        if (!confirmed || !mounted) return;
        if (await _run(() => service.delete(group.id), l10n.groupDeleted)) {
          _close();
        }
    }
  }

  void _close() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoute.home.name);
    }
  }

  /// Lance [action] et en affiche l'issue ; vrai si elle a réussi.
  Future<bool> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
      return true;
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
      return false;
    }
  }
}

/// Personne ne déplace un créneau d'un autre ; pas de création par glisser.
final _readOnly = KalenderInteraction(
  allowResizing: false,
  allowRescheduling: false,
  allowEventCreation: false,
);

final class _GroupEvent extends KalenderEvent {
  _GroupEvent(
    GroupAgendaItem item, {
    required Color color,
    required String owner,
  }) : this._at(item, color, owner, item.localStart, item.localEnd);

  _GroupEvent._at(
    this.item,
    this.color,
    this.owner,
    DateTime start,
    DateTime end,
  ) : super(
        id: item.instanceKey,
        start: start,
        end: end,
        isAllDay: item.isAllDay,
        interaction: EventInteraction.allowNone(),
      );

  final GroupAgendaItem item;
  final Color color;

  /// Nom du membre, « Vous », ou « Groupe ».
  final String owner;

  @override
  _GroupEvent copyWithData({required DateTime start, required DateTime end}) =>
      _GroupEvent._at(item, color, owner, start, end);
}

const _tileComponents = TileComponents(tileBuilder: _buildTile);

Widget _buildTile(
  BuildContext context,
  KalenderEvent event,
  KalenderDateTimeRange tileRange,
) {
  final groupEvent = event is _GroupEvent ? event : null;
  final background =
      groupEvent?.color ?? Theme.of(context).colorScheme.primaryContainer;
  final foreground = readableOn(background);
  final title = groupEvent?.item.title;
  return Container(
    margin: const EdgeInsets.all(1),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      // Un créneau « occupé » est plus pâle : on n'en sait pas plus.
      color: title == null ? background.withValues(alpha: 0.55) : background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      title ?? AppLocalizations.of(context).busyLabel,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: foreground, fontSize: 12),
    ),
  );
}

class _MemberChips extends StatelessWidget {
  const _MemberChips({
    required this.members,
    required this.hidden,
    required this.onToggle,
  });

  final List<GroupMember> members;
  final Set<String> hidden;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          for (final (rank, member) in members.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: GroupKeys.memberChip(member.userId),
                avatar: CircleAvatar(
                  backgroundColor: memberColor(rank, colors),
                  radius: 6,
                ),
                label: Text(member.isMe ? l10n.memberYou : member.displayName),
                selected: !hidden.contains(member.userId),
                showCheckmark: false,
                onSelected: (_) => onToggle(member.userId),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupMenu extends StatelessWidget {
  const _GroupMenu({required this.group, required this.onSelected});

  final MyGroup group;
  final void Function(_MenuAction action, MyGroup group) onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<_MenuAction>(
      key: GroupKeys.menu,
      onSelected: (action) => onSelected(action, group),
      itemBuilder: (context) => [
        if (group.role.canManage)
          PopupMenuItem(
            key: GroupKeys.rename,
            value: _MenuAction.rename,
            child: Text(l10n.renameGroup),
          ),
        PopupMenuItem(
          key: GroupKeys.leave,
          value: _MenuAction.leave,
          child: Text(l10n.leaveGroup),
        ),
        if (group.role == GroupRole.owner)
          PopupMenuItem(
            key: GroupKeys.delete,
            value: _MenuAction.delete,
            child: Text(l10n.deleteGroup),
          ),
      ],
    );
  }
}
