/// Onglet « Social » de l'accueil : les dates à retenir des proches, les
/// proches, puis les groupes. Un seul bouton « Ajouter » propose d'ajouter
/// un proche, de créer un groupe ou d'en rejoindre un avec un code.
///
/// Choix non évident : l'onglet ne fait qu'assembler — chaque section vient
/// de sa feature (proches : agenda ; groupes : groupes), qui garde ses
/// écrans et ses actions.
library;

import 'package:agora/src/features/calendar/presentation/contacts_section.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/groups_section.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract final class SocialKeys {
  static const screen = ValueKey('social.screen');
  static const add = ValueKey('social.add');
  static const addContact = ValueKey('social.add.contact');
  static const upcoming = ValueKey('social.upcoming');
}

enum _AddChoice { contact, group, join }

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<_AddChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: SocialKeys.addContact,
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: Text(l10n.newContactButton),
              subtitle: Text(l10n.newContactHint),
              onTap: () => Navigator.of(context).pop(_AddChoice.contact),
            ),
            ListTile(
              key: GroupKeys.newGroup,
              leading: const Icon(Icons.group_add_outlined),
              title: Text(l10n.newGroupButton),
              onTap: () => Navigator.of(context).pop(_AddChoice.group),
            ),
            ListTile(
              key: GroupKeys.joinWithCode,
              leading: const Icon(Icons.login),
              title: Text(l10n.joinWithCodeButton),
              onTap: () => Navigator.of(context).pop(_AddChoice.join),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _AddChoice.contact:
        await addContact(context, ref);
      case _AddChoice.group:
        await createGroup(context, ref);
      case _AddChoice.join:
        await joinGroupWithCode(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: SocialKeys.screen,
      floatingActionButton: FloatingActionButton.extended(
        key: SocialKeys.add,
        // Les onglets de l'accueil coexistent : chaque bouton a son tag.
        heroTag: SocialKeys.add,
        icon: const Icon(Icons.add),
        label: Text(l10n.socialAddButton),
        onPressed: () => _add(context, ref),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: const [
          UpcomingAnniversaries(sectionKey: SocialKeys.upcoming),
          ContactsSection(),
          GroupsSection(),
        ],
      ),
    );
  }
}
