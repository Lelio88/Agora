/// Salon Discord d'un groupe : lequel est relié, et ce que le bot y publie.
///
/// Qui peut quoi (le serveur le vérifie de toute façon) :
/// - tout membre voit si un salon est relié ;
/// - un admin invite le bot, crée le code de liaison, règle le récap et les
///   rappels, et délie le salon.
///
/// Choix non évidents :
/// - la liaison se termine dans Discord (`/relier CODE`), hors de l'app :
///   l'écran ne peut pas le savoir seul, d'où « J'ai tapé la commande », qui
///   relit le salon ;
/// - chaque réglage s'enregistre aussitôt choisi : il n'y a pas de bouton
///   « Enregistrer » à oublier ;
/// - l'avertissement sur ce que voit le salon est toujours affiché à qui
///   règle les publications : un salon déborde souvent du groupe.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/config/discord_bot.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/discord/application/discord_providers.dart';
import 'package:agora/src/features/discord/domain/discord.dart';
import 'package:agora/src/features/discord/presentation/discord_keys.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DiscordChannelScreen extends ConsumerWidget {
  const DiscordChannelScreen({required this.groupId, super.key});

  final String groupId;

  static Future<void> show(BuildContext context, String groupId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DiscordChannelScreen(groupId: groupId),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canManage =
        ref.watch(myGroupProvider(groupId)).value?.role.canManage ?? false;
    return Scaffold(
      key: DiscordKeys.channelScreen,
      appBar: AppBar(title: Text(l10n.discordChannelTitle)),
      body: AsyncValueWidget<DiscordChannel?>(
        value: ref.watch(discordChannelProvider(groupId)),
        data: (channel) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (channel == null) ...[
              Text(l10n.discordChannelNone),
              const SizedBox(height: 8),
              if (canManage)
                _LinkSteps(groupId: groupId)
              else
                Text(l10n.discordChannelAskAdmin),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tag),
                title: Text(
                  channel.channelName.isEmpty
                      ? l10n.discordChannelLinkedUnnamed
                      : l10n.discordChannelLinked(channel.channelName),
                ),
              ),
              if (canManage) _ChannelSettings(channel: channel),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mode d'emploi de la liaison, pour un admin : inviter le bot, créer un
/// code, le taper dans le salon.
class _LinkSteps extends ConsumerStatefulWidget {
  const _LinkSteps({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_LinkSteps> createState() => _LinkStepsState();
}

class _LinkStepsState extends ConsumerState<_LinkSteps> {
  String? _code;
  bool _busy = false;

  Future<void> _createCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final code = await ref
          .read(discordServiceProvider)
          .createLinkCode(widget.groupId);
      if (mounted) setState(() => _code = code);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String command) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: command));
    messenger.showSnackBar(SnackBar(content: Text(l10n.discordCommandCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final invite = ref.watch(discordBotInviteProvider);
    final code = _code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.discordLinkSteps),
        const SizedBox(height: 16),
        if (invite != null) ...[
          OutlinedButton.icon(
            key: DiscordKeys.inviteBot,
            onPressed: () => ref.read(linkOpenerProvider).open(invite),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.discordInviteBot),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton(
          key: DiscordKeys.createCode,
          onPressed: _busy ? null : _createCode,
          child: Text(l10n.discordCreateCode),
        ),
        if (code != null) ...[
          const SizedBox(height: 16),
          Text(l10n.discordCodeInstructions),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  l10n.discordLinkCommand(code),
                  key: DiscordKeys.linkCommand,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                key: DiscordKeys.copyCommand,
                tooltip: l10n.discordCopyCommand,
                onPressed: () => _copy(l10n.discordLinkCommand(code)),
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            key: DiscordKeys.checkLink,
            onPressed: () =>
                ref.read(discordServiceProvider).refresh(widget.groupId),
            child: Text(l10n.discordCheckLink),
          ),
        ],
      ],
    );
  }
}

/// Réglages des publications, pour un admin ; chaque choix s'enregistre.
class _ChannelSettings extends ConsumerWidget {
  const _ChannelSettings({required this.channel});

  final DiscordChannel channel;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    DiscordChannel next,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(discordServiceProvider).save(next);
      messenger.showSnackBar(SnackBar(content: Text(l10n.discordSaved)));
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(discordServiceProvider).unlinkChannel(channel.groupId);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // 5 janvier 2026 : un lundi, point de départ des jours de la semaine.
    String weekdayName(int weekday) =>
        DateFormat.EEEE(locale).format(DateTime(2026, 1, 4 + weekday));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.visibility_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.discordPublicNotice)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.discordRecapLabel, style: text.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<DiscordRecap>(
          key: DiscordKeys.recap,
          segments: [
            ButtonSegment(
              value: DiscordRecap.off,
              label: Text(l10n.discordRecapOff),
            ),
            ButtonSegment(
              value: DiscordRecap.daily,
              label: Text(l10n.discordRecapDaily),
            ),
            ButtonSegment(
              value: DiscordRecap.weekly,
              label: Text(l10n.discordRecapWeekly),
            ),
          ],
          selected: {channel.recap},
          onSelectionChanged: (selection) =>
              _save(context, ref, channel.copyWith(recap: selection.first)),
        ),
        if (channel.recap != DiscordRecap.off) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (channel.recap == DiscordRecap.weekly) ...[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: DiscordKeys.recapWeekday,
                    initialValue: channel.recapWeekday,
                    decoration: InputDecoration(
                      labelText: l10n.discordRecapDay,
                    ),
                    items: [
                      for (var day = 1; day <= 7; day++)
                        DropdownMenuItem(
                          value: day,
                          child: Text(weekdayName(day)),
                        ),
                    ],
                    onChanged: (day) {
                      if (day == null) return;
                      _save(context, ref, channel.copyWith(recapWeekday: day));
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: DiscordKeys.recapHour,
                  initialValue: channel.recapHour,
                  decoration: InputDecoration(
                    labelText: l10n.discordRecapHour,
                    helperText: l10n.discordRecapTimezone(channel.timezone),
                  ),
                  items: [
                    for (var hour = 0; hour < 24; hour++)
                      DropdownMenuItem(
                        value: hour,
                        child: Text(l10n.discordRecapHourValue(hour)),
                      ),
                  ],
                  onChanged: (hour) {
                    if (hour == null) return;
                    _save(context, ref, channel.copyWith(recapHour: hour));
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        DropdownButtonFormField<int?>(
          key: DiscordKeys.reminder,
          initialValue: channel.reminderMinutes,
          decoration: InputDecoration(labelText: l10n.discordReminderLabel),
          items: [
            DropdownMenuItem(child: Text(l10n.discordReminderOff)),
            for (final minutes in discordReminderChoices)
              DropdownMenuItem(
                value: minutes,
                child: Text(switch (minutes) {
                  15 => l10n.discordReminder15,
                  60 => l10n.discordReminder60,
                  _ => l10n.discordReminder1440,
                }),
              ),
          ],
          onChanged: (minutes) => _save(
            context,
            ref,
            channel.copyWith(reminderMinutes: () => minutes),
          ),
        ),
        const SizedBox(height: 32),
        TextButton(
          key: DiscordKeys.unlinkChannel,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => _unlink(context, ref),
          child: Text(l10n.discordUnlinkChannel),
        ),
      ],
    );
  }
}
