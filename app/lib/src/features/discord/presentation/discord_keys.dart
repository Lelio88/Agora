/// Clés des écrans Discord, pour les tests.
library;

import 'package:flutter/widgets.dart';

abstract final class DiscordKeys {
  // Compte, dans le profil.
  static const account = ValueKey('discord.account');
  static const linkAccount = ValueKey('discord.account.link');
  static const unlinkAccount = ValueKey('discord.account.unlink');

  // Salon d'un groupe.
  static const channelScreen = ValueKey('discord.channel');
  static const inviteBot = ValueKey('discord.channel.inviteBot');
  static const createCode = ValueKey('discord.channel.createCode');
  static const linkCommand = ValueKey('discord.channel.command');
  static const copyCommand = ValueKey('discord.channel.copy');
  static const checkLink = ValueKey('discord.channel.check');
  static const recap = ValueKey('discord.channel.recap');
  static const recapWeekday = ValueKey('discord.channel.weekday');
  static const recapHour = ValueKey('discord.channel.hour');
  static const reminder = ValueKey('discord.channel.reminder');
  static const unlinkChannel = ValueKey('discord.channel.unlink');
}
