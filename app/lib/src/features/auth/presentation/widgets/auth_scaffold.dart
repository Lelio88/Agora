/// Mise en page commune des écrans de compte : colonne centrée, largeur
/// bornée (lisible sur le web comme sur un téléphone), défilante quand le
/// clavier réduit l'espace.
///
/// Invariant : pendant une action ([busy]), tout l'écran ignore les appuis,
/// liens secondaires compris. Sinon on pourrait changer d'écran pendant la
/// requête, et sa réussite (session ouverte) ferait rediriger le routeur
/// depuis l'écran suivant, en perdant la saisie en cours.
library;

import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

const _maxFormWidth = 420.0;

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.busy = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Une action est en cours : l'écran ignore les appuis.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxFormWidth),
              child: AbsorbPointer(
                absorbing: busy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppLocalizations.of(context).appTitle,
                      textAlign: TextAlign.center,
                      style: text.displaySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: text.titleLarge,
                    ),
                    if (subtitle case final subtitle?) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne « Pas encore de compte ? Créer un compte » : texte et lien, qui
/// passent à la ligne sur un écran étroit.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    required this.prompt,
    required this.action,
    required this.onPressed,
    this.actionKey,
    super.key,
  });

  /// Clé posée sur le lien lui-même, pas sur toute la ligne : un appui au
  /// centre de la ligne tomberait sinon sur le texte.
  final Key? actionKey;
  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(prompt),
      TextButton(key: actionKey, onPressed: onPressed, child: Text(action)),
    ],
  );
}
