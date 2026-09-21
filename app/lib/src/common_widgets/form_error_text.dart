/// Message d'erreur d'un formulaire, affiché au-dessus de son bouton. Le
/// texte vient toujours de `messageFor` (l10n), jamais d'une exception brute.
library;

import 'package:flutter/material.dart';

class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: TextStyle(color: colors.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}
