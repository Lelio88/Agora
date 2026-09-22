/// Libellés et couleurs communs aux écrans de groupes : rôle, partage,
/// couleur d'un membre, et la confirmation des actions qui ne se défont pas.
///
/// La couleur d'un membre tient à son rang d'arrivée dans le groupe : elle
/// reste la même d'un écran à l'autre et d'une visite à l'autre.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

String roleLabel(GroupRole role, AppLocalizations l10n) => switch (role) {
  GroupRole.owner => l10n.groupRoleOwner,
  GroupRole.admin => l10n.groupRoleAdmin,
  GroupRole.member => l10n.groupRoleMember,
};

String shareLevelLabel(ShareLevel level, AppLocalizations l10n) =>
    switch (level) {
      ShareLevel.details => l10n.shareDetails,
      ShareLevel.busy => l10n.shareBusy,
      ShareLevel.invisible => l10n.shareNothing,
    };

/// Couleur du membre arrivé en position [rank] (0 : le premier).
Color memberColor(int rank, ColorScheme colors) =>
    colorFromHex(appPalette[rank % appPalette.length], colors.primary);

/// Demande confirmation d'une action qui ne se défait pas ; vrai si oui.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: GroupKeys.confirm,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
