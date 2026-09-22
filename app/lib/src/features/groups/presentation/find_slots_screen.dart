/// Créneaux communs d'un groupe : les plages où tous les membres choisis
/// sont libres, sur les prochains jours, dans une fenêtre horaire. Un appui
/// sur un créneau le propose au groupe.
///
/// Ouvert par la route `/groups/:groupId/slots`. Le calcul
/// (`domain/free_slots.dart`) part de l'agenda du groupe, déjà passé par la
/// règle de vie privée : l'écran ne voit rien de plus que l'agenda
/// superposé.
///
/// Choix non évidents :
/// - durée et période restent en vue ; heures, week-ends, journées entières
///   et membres se replient, pour que les créneaux s'affichent sans
///   défiler sur un téléphone ;
/// - un membre qui ne partage rien paraît toujours libre : l'écran le dit,
///   nommément, plutôt que de promettre un créneau qu'il ne peut vérifier ;
/// - proposer un créneau ouvre l'éditeur de la feature agenda par son nom
///   de route, début et fin préremplis ; au retour, l'agenda se relit.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/free_slots.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Durées proposées, en minutes.
const slotDurations = [30, 60, 90, 120, 180];

/// Périodes proposées, en jours (l'agenda d'un groupe se lit par
/// trimestre au plus).
const slotPeriods = [7, 14, 30];

class FindSlotsScreen extends ConsumerStatefulWidget {
  const FindSlotsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<FindSlotsScreen> createState() => _FindSlotsScreenState();
}

class _FindSlotsScreenState extends ConsumerState<FindSlotsScreen> {
  int _minutes = 60;
  int _days = 7;
  TimeOfDay _notBefore = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _notAfter = const TimeOfDay(hour: 22, minute: 0);
  bool _weekends = true;
  bool _allDayBlocks = false;

  /// Membres écartés de la recherche ; tous comptent au départ.
  final _left = <String>{};

  /// Début de la période : minuit aujourd'hui, figé à l'ouverture pour que
  /// la requête ne change pas à chaque reconstruction.
  late final DateTime _today = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();

  GroupAgendaQuery get _query => GroupAgendaQuery(
    groupId: widget.groupId,
    from: _today.toUtc(),
    to: DateTime(_today.year, _today.month, _today.day + _days).toUtc(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(groupMembersProvider(widget.groupId));
    final agenda = ref.watch(groupAgendaProvider(_query));
    return Scaffold(
      key: GroupKeys.slotsScreen,
      appBar: AppBar(title: Text(l10n.findSlotTitle)),
      body: AsyncValueWidget<List<GroupMember>>(
        value: members,
        data: (list) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            ..._criteria(context, list),
            const Divider(),
            AsyncValueWidget(
              value: agenda,
              data: (items) => _Results(
                slots: findFreeSlots(
                  SlotSearch(
                    from: DateTime.now().isAfter(_today)
                        ? DateTime.now()
                        : _today,
                    to: DateTime(_today.year, _today.month, _today.day + _days),
                    duration: Duration(minutes: _minutes),
                    dayStart: _offset(_notBefore),
                    dayEnd: _offset(_notAfter),
                    weekdays: {
                      for (
                        var day = DateTime.monday;
                        day <= DateTime.sunday;
                        day++
                      )
                        if (_weekends || day < DateTime.saturday) day,
                    },
                    members: {
                      for (final member in list)
                        if (!_left.contains(member.userId)) member.userId,
                    },
                    allDayBlocks: _allDayBlocks,
                  ),
                  items,
                ),
                onPropose: _propose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _criteria(BuildContext context, List<GroupMember> members) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hidden = [
      for (final member in members)
        if (!member.isMe &&
            !_left.contains(member.userId) &&
            member.shareLevel == ShareLevel.invisible)
          member.displayName,
    ];
    return [
      _Section(title: l10n.slotDurationLabel),
      _Choices<int>(
        values: slotDurations,
        selected: _minutes,
        keyOf: GroupKeys.slotDuration,
        label: (minutes) => durationLabel(Duration(minutes: minutes), l10n),
        onSelected: (minutes) => setState(() => _minutes = minutes),
      ),
      _Section(title: l10n.slotPeriodLabel),
      _Choices<int>(
        values: slotPeriods,
        selected: _days,
        keyOf: GroupKeys.slotPeriod,
        label: l10n.slotPeriodDays,
        onSelected: (days) => setState(() => _days = days),
      ),
      ExpansionTile(
        key: GroupKeys.slotMore,
        title: Text(l10n.slotMoreCriteria),
        children: [
          ListTile(
            key: GroupKeys.slotNotBefore,
            leading: const Icon(Icons.schedule),
            title: Text(l10n.slotNotBeforeLabel),
            trailing: Text(_notBefore.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _notBefore,
              );
              if (picked != null) setState(() => _notBefore = picked);
            },
          ),
          ListTile(
            key: GroupKeys.slotNotAfter,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n.slotNotAfterLabel),
            trailing: Text(_notAfter.format(context)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _notAfter,
              );
              if (picked != null) setState(() => _notAfter = picked);
            },
          ),
          SwitchListTile(
            key: GroupKeys.slotWeekends,
            title: Text(l10n.slotWeekendsLabel),
            value: _weekends,
            onChanged: (value) => setState(() => _weekends = value),
          ),
          SwitchListTile(
            key: GroupKeys.slotAllDay,
            title: Text(l10n.slotAllDayLabel),
            value: _allDayBlocks,
            onChanged: (value) => setState(() => _allDayBlocks = value),
          ),
          _Section(title: l10n.slotMembersLabel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final member in members)
                  FilterChip(
                    key: GroupKeys.slotMember(member.userId),
                    label: Text(
                      member.isMe ? l10n.memberYou : member.displayName,
                    ),
                    selected: !_left.contains(member.userId),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _left.remove(member.userId);
                      } else {
                        _left.add(member.userId);
                      }
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
      if (hidden.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l10n.slotInvisibleNote(hidden.join(', '), hidden.length),
            key: GroupKeys.slotInvisibleNote,
            style: textTheme.bodySmall,
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(l10n.slotsHint, style: textTheme.bodySmall),
      ),
    ];
  }

  static Duration _offset(TimeOfDay time) =>
      Duration(hours: time.hour, minutes: time.minute);

  /// Propose un rdv du groupe sur le début du créneau, pour la durée
  /// cherchée ; au retour, relit l'agenda (le créneau n'est plus libre).
  Future<void> _propose(FreeSlot slot) async {
    final start = slot.start;
    await context.pushNamed<bool>(
      AppRoute.groupEventNew.name,
      pathParameters: {'groupId': widget.groupId},
      queryParameters: {
        'start': start.toUtc().toIso8601String(),
        'end': start.add(Duration(minutes: _minutes)).toUtc().toIso8601String(),
      },
    );
    if (mounted) ref.invalidate(groupAgendaProvider);
  }
}

/// « 1 h 30 », « 45 min », « 2 h ».
String durationLabel(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return l10n.durationMinutes(minutes);
  if (minutes == 0) return l10n.durationHours(hours);
  return l10n.durationHoursMinutes(hours, minutes);
}

class _Results extends StatelessWidget {
  const _Results({required this.slots, required this.onPropose});

  final List<FreeSlot> slots;
  final ValueChanged<FreeSlot> onPropose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(l10n.slotsNone, key: GroupKeys.slotsNone),
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.MMMEd(locale);
    final time = DateFormat.Hm(locale);
    return Column(
      children: [
        for (final (index, slot) in slots.indexed)
          ListTile(
            key: GroupKeys.slotTile(index),
            leading: const Icon(Icons.event_available_outlined),
            title: Text(date.format(slot.start)),
            subtitle: Text(
              '${time.format(slot.start)} – ${time.format(slot.end)} · '
              '${durationLabel(slot.length, l10n)}',
            ),
            trailing: Tooltip(
              message: l10n.proposeEventButton,
              child: const Icon(Icons.add),
            ),
            onTap: () => onPropose(slot),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.keyOf,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final Key Function(T value) keyOf;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            key: keyOf(value),
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    ),
  );
}
