/// Lien d'installation du bot Discord sur un serveur.
///
/// L'identifiant de l'application Discord vient du build
/// (`AGORA_DISCORD_APPLICATION_ID`, dans `config/<env>.json`) : il n'est pas
/// secret, mais propre à chaque environnement. Sans lui, l'app ne propose
/// pas d'installer le bot plutôt qu'un lien faux.
///
/// Droits demandés : voir les salons (1024) et y écrire (2048), rien de
/// plus — le bot ne lit aucun message.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

const _viewAndSend = 1024 | 2048;

/// Lien d'installation, ou `null` si l'identifiant n'est pas un nombre.
Uri? discordBotInviteLink(String applicationId) {
  final id = applicationId.trim();
  if (!RegExp(r'^[0-9]{1,20}$').hasMatch(id)) return null;
  return Uri.https('discord.com', '/oauth2/authorize', {
    'client_id': id,
    'scope': 'bot applications.commands',
    'permissions': '$_viewAndSend',
  });
}

final discordBotInviteProvider = Provider<Uri?>(
  (ref) => discordBotInviteLink(
    const String.fromEnvironment('AGORA_DISCORD_APPLICATION_ID'),
  ),
);
