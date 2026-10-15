/// « Partager mon profil » : les liens de l'utilisateur, chacun avec son nom
/// (« Pour Marie ») et son niveau, et le bouton qui en crée un.
///
/// Choix non évidents :
/// - un lien tout juste créé ouvre aussitôt sa fenêtre (QR code, partage) :
///   c'est la suite évidente, il n'y a rien d'autre à en faire ;
/// - le niveau se choisit à la création et ne change plus : pour donner plus
///   ou moins à quelqu'un, on crée un autre lien et on supprime le premier.
///   Le serveur ne permet d'ailleurs pas de modifier un lien ;
/// - les agendas partagés se cochent à la création, tous cochés au départ
///   (rien ne sort qu'on n'ait vu) ; il en faut au moins un. Ceux d'un proche
///   ou invisibles ne sont pas proposés : ils ne sortiraient pas.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/profile_link/application/profile_link_providers.dart';
import 'package:agora/src/features/profile_link/domain/profile_link.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_keys.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_labels.dart';
import 'package:agora/src/features/profile_link/presentation/profile_link_sheet.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileLinksScreen extends ConsumerWidget {
  const ProfileLinksScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft =
        await showDialog<
          ({String label, ProfileLinkLevel level, List<String> calendarIds})
        >(context: context, builder: (_) => const _NewLinkDialog());
    if (draft == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final link = await ref
          .read(profileLinkServiceProvider)
          .create(
            label: draft.label,
            level: draft.level,
            calendarIds: draft.calendarIds,
          );
      if (context.mounted) await showProfileLinkSheet(context, link);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mine = ref.watch(shareableCalendarsProvider).value ?? const [];
    return Scaffold(
      key: ProfileLinkKeys.screen,
      appBar: AppBar(title: Text(l10n.profileLinksTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: ProfileLinkKeys.newLink,
        icon: const Icon(Icons.add),
        label: Text(l10n.profileLinkNew),
        onPressed: () => _create(context, ref),
      ),
      body: AsyncValueWidget<List<ProfileLink>>(
        value: ref.watch(myProfileLinksProvider),
        data: (links) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.profileLinksIntro),
            ),
            if (links.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.profileLinksEmpty),
              ),
            for (final link in links)
              ListTile(
                key: ProfileLinkKeys.tile(link.code),
                leading: const Icon(Icons.qr_code_2),
                title: Text(link.label),
                isThreeLine: true,
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(levelLine(link.level, l10n)),
                    Text(calendarsLine(link, mine, l10n)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showProfileLinkSheet(context, link),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nom et niveau d'un nouveau lien : rend les deux, ou `null` si l'on renonce.
class _NewLinkDialog extends ConsumerStatefulWidget {
  const _NewLinkDialog();

  @override
  ConsumerState<_NewLinkDialog> createState() => _NewLinkDialogState();
}

class _NewLinkDialogState extends ConsumerState<_NewLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();

  // « Occupé » d'abord : le moins bavard des deux, jamais imposé.
  ProfileLinkLevel _level = ProfileLinkLevel.busy;

  // Les agendas décochés ; tous le sont au départ.
  final _unticked = <String>{};
  bool _noCalendar = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _submit(List<ShareableCalendar> mine) {
    final valid = _formKey.currentState?.validate() ?? false;
    final ids = [
      for (final calendar in mine)
        if (!_unticked.contains(calendar.id)) calendar.id,
    ];
    setState(() => _noCalendar = ids.isEmpty);
    if (!valid || ids.isEmpty) return;
    Navigator.of(context)
        .pop((label: _label.text.trim(), level: _level, calendarIds: ids));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mine = ref.watch(shareableCalendarsProvider).value ?? const [];
    return AlertDialog(
      title: Text(l10n.profileLinkNew),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: ProfileLinkKeys.labelField,
                controller: _label,
                autofocus: true,
                maxLength: profileLinkLabelMaxLength,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.profileLinkLabelField,
                  hintText: l10n.profileLinkLabelHint,
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.profileLinkLabelRequired
                    : null,
                onFieldSubmitted: (_) => _submit(mine),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.profileLinkLevelQuestion,
                style: theme.textTheme.titleMedium,
              ),
              RadioGroup<ProfileLinkLevel>(
                groupValue: _level,
                onChanged: (level) {
                  if (level != null) setState(() => _level = level);
                },
                child: Column(
                  children: [
                    for (final (level, label) in [
                      (ProfileLinkLevel.busy, l10n.shareBusy),
                      (ProfileLinkLevel.details, l10n.shareDetails),
                    ])
                      RadioListTile<ProfileLinkLevel>(
                        key: ProfileLinkKeys.levelOption(level),
                        value: level,
                        title: Text(label),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              Text(l10n.profileLinkLevelHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(
                l10n.profileLinkCalendarsQuestion,
                style: theme.textTheme.titleMedium,
              ),
              for (final calendar in mine)
                CheckboxListTile(
                  key: ProfileLinkKeys.calendarOption(calendar.id),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: !_unticked.contains(calendar.id),
                  title: Text(calendar.name),
                  onChanged: (ticked) => setState(() {
                    _noCalendar = false;
                    if (ticked ?? false) {
                      _unticked.remove(calendar.id);
                    } else {
                      _unticked.add(calendar.id);
                    }
                  }),
                ),
              if (_noCalendar)
                Text(
                  l10n.profileLinkCalendarsRequired,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                )
              else
                Text(
                  l10n.profileLinkCalendarsHint,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          key: ProfileLinkKeys.create,
          onPressed: () => _submit(mine),
          child: Text(l10n.profileLinkCreateButton),
        ),
      ],
    );
  }
}
