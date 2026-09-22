/// Choix de la couleur d'un agenda dans la palette de l'app : partagé par
/// l'éditeur d'agenda et l'import par lien.
library;

import 'package:agora/src/common_widgets/palette.dart';
import 'package:agora/src/features/calendar/presentation/calendar_keys.dart';
import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  const ColorPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final fallback = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final hex in appPalette)
          Semantics(
            selected: hex == selected,
            button: true,
            child: InkWell(
              key: CalendarKeys.calendarColor(hex),
              customBorder: const CircleBorder(),
              onTap: () => onSelected(hex),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorFromHex(hex, fallback),
                child: hex == selected
                    ? Icon(
                        Icons.check,
                        color: readableOn(colorFromHex(hex, fallback)),
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
