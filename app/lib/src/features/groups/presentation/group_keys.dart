/// Clés des écrans de groupes, pour les tests.
library;

import 'package:agora/src/common_widgets/agenda_view.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:flutter/widgets.dart';

abstract final class GroupKeys {
  // Liste des groupes.
  static const listScreen = ValueKey('groups.screen');
  static const newGroup = ValueKey('groups.new');
  static const discord = ValueKey('groups.menu.discord');
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
  static const findSlots = ValueKey('group.findSlots');
  static const myShareChip = ValueKey('group.myShareChip');

  // Créneaux communs.
  static const slotsScreen = ValueKey('group.slots');
  static const slotMore = ValueKey('group.slots.more');
  static const slotNotBefore = ValueKey('group.slots.notBefore');
  static const slotNotAfter = ValueKey('group.slots.notAfter');
  static const slotWeekends = ValueKey('group.slots.weekends');
  static const slotAllDay = ValueKey('group.slots.allDay');
  static const slotInvisibleNote = ValueKey('group.slots.invisibleNote');
  static const slotsNone = ValueKey('group.slots.none');
  static ValueKey<String> slotDuration(int minutes) =>
      ValueKey('group.slots.duration.$minutes');
  static ValueKey<String> slotPeriod(int days) =>
      ValueKey('group.slots.period.$days');
  static ValueKey<String> slotMember(String userId) =>
      ValueKey('group.slots.member.$userId');
  static ValueKey<String> slotTile(int index) =>
      ValueKey('group.slots.tile.$index');
  static const toolbar = AgendaToolbarKeys('group');
  static ValueKey<String> memberChip(String userId) =>
      ValueKey('group.chip.$userId');

  // Invitation.
  static const inviteCode = ValueKey('group.invite.code');
  static const copyCode = ValueKey('group.invite.copyCode');
  static const copyLink = ValueKey('group.invite.copyLink');
  static const revokeInvite = ValueKey('group.invite.revoke');
  static const shareInvite = ValueKey('group.invite.share');
  static const pasteCode = ValueKey('groups.join.paste');

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

  // Jumelage.
  static const twinScreen = ValueKey('group.twin.screen');
  static const twinMenu = ValueKey('group.menu.twin');
  static const twinConfirm = ValueKey('group.twin.confirm');
  static const twinLink = ValueKey('group.twin.link');
  static const twinNewGroupOption = ValueKey('group.twin.newGroup');
  static const twinNameField = ValueKey('group.twin.name');
  static ValueKey<String> twinGroupOption(String groupId) =>
      ValueKey('group.twin.group.$groupId');
  static ValueKey<String> twinStart(TwinApp app) =>
      ValueKey('group.twin.${app.name}.start');
  static ValueKey<String> twinUnlink(TwinApp app) =>
      ValueKey('group.twin.${app.name}.unlink');
  static ValueKey<String> twinJoin(TwinApp app) =>
      ValueKey('group.twin.${app.name}.join');
}
