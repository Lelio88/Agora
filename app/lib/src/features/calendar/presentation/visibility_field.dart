/// Choix de ce que voient les membres de ses groupes : « selon le groupe »,
/// « occupé, sans détail » ou « invisible ». Sert au rdv comme à l'agenda,
/// qui ne peuvent que restreindre le réglage du groupe (jamais « détails »).
library;

import 'package:agora/src/features/calendar/domain/event_visibility.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

/// Libellé d'un niveau de masquage ; `null` : selon le groupe.
String visibilityLabel(EventVisibility? visibility, AppLocalizations l10n) =>
    switch (visibility) {
      null || EventVisibility.details => l10n.visibilityInherit,
      EventVisibility.busy => l10n.visibilityBusy,
      EventVisibility.invisible => l10n.visibilityInvisible,
    };

class VisibilityField extends StatelessWidget {
  const VisibilityField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final EventVisibility? value;
  final ValueChanged<EventVisibility?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(EventVisibility? visibility) =>
        visibilityLabel(visibility, l10n);
    return PopupMenuButton<EventVisibility?>(
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in [
          null,
          EventVisibility.busy,
          EventVisibility.invisible,
        ])
          PopupMenuItem<EventVisibility?>(
            value: option,
            child: Text(label(option)),
          ),
      ],
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.visibility_outlined),
        title: Text(l10n.visibilityLabel),
        subtitle: Text(label(value)),
        trailing: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}
