/// Nom à montrer d'un assistant reconnu, dans la langue de l'interface.
library;

import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:agora/src/localization/app_localizations.dart';

String assistantLabel(KnownAssistant assistant, AppLocalizations l10n) =>
    switch (assistant) {
      KnownAssistant.claude => 'Claude',
      KnownAssistant.chatGpt => 'ChatGPT',
      KnownAssistant.vsCode => 'VS Code',
      KnownAssistant.cursor => 'Cursor',
      KnownAssistant.localTool => l10n.assistantLocalTool,
    };
