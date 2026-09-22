/// Clés des écrans de groupes, pour les tests.
library;

import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:flutter/widgets.dart';

abstract final class GroupKeys {
  // Liste des groupes.
  static const listScreen = ValueKey('groups.screen');
  static const newGroup = ValueKey('groups.new');
  static const joinWithCode = ValueKey('groups.joinWithCode');
  static ValueKey<String> groupTile(String id) => ValueKey('groups.tile.$id');

  // Création et renommage.
  static const editor = ValueKey('groups.editor');
  static const name = ValueKey('groups.editor.name');
  static const description = ValueKey('groups.editor.description');
  static const save = ValueKey('groups.editor.save');

  // Rejoindre.
  static const joinScreen = ValueKey('groups.join');
  static const codeField = ValueKey('groups.join.code');
  static const continueButton = ValueKey('groups.join.continue');
  static const joinButton = ValueKey('groups.join.submit');
  static const openGroup = ValueKey('groups.join.open');
  static ValueKey<String> shareOption(ShareLevel level) =>
      ValueKey('groups.join.share.${level.name}');

  // Agenda d'un groupe.
  static const groupScreen = ValueKey('group.screen');
  static const invite = ValueKey('group.invite');
  static const members = ValueKey('group.members');
  static const menu = ValueKey('group.menu');
  static const rename = ValueKey('group.menu.rename');
  static const leave = ValueKey('group.menu.leave');
  static const delete = ValueKey('group.menu.delete');
  static const confirm = ValueKey('group.confirm');
  static const refresh = ValueKey('group.refresh');
  static const proposeEvent = ValueKey('group.proposeEvent');
  static const toolbar = AgendaToolbarKeys('group');
  static ValueKey<String> memberChip(String userId) =>
      ValueKey('group.chip.$userId');

  // Invitation.
  static const inviteCode = ValueKey('group.invite.code');
  static const copyCode = ValueKey('group.invite.copyCode');
  static const copyLink = ValueKey('group.invite.copyLink');
  static const revokeInvite = ValueKey('group.invite.revoke');

  // Membres.
  static const membersScreen = ValueKey('group.membersScreen');
  static ValueKey<String> myShare(ShareLevel level) =>
      ValueKey('group.myShare.${level.name}');
  static ValueKey<String> memberTile(String userId) =>
      ValueKey('group.member.$userId');
  static ValueKey<String> memberMenu(String userId) =>
      ValueKey('group.member.$userId.menu');
  static const makeAdmin = ValueKey('group.member.makeAdmin');
  static const removeAdmin = ValueKey('group.member.removeAdmin');
  static const transfer = ValueKey('group.member.transfer');
  static const remove = ValueKey('group.member.remove');
}
