/// Un groupe vu par l'un de ses membres : le groupe, ses membres, ses
/// invitations.
///
/// Vocabulaire :
/// - le **rôle** (propriétaire, admin, membre) dit ce qu'on peut gérer ;
/// - le **partage** ([ShareLevel]) dit ce que les autres membres voient de
///   son agenda personnel. C'est un plafond : un agenda ou un rdv masqué le
///   reste, quel que soit le partage (le plus restrictif l'emporte).
library;

enum GroupRole {
  owner,
  admin,
  member;

  static GroupRole fromCode(String code) =>
      values.firstWhere((role) => role.name == code, orElse: () => member);

  /// Renomme le groupe, révoque des invitations, exclut des membres.
  bool get canManage => this != member;
}

enum ShareLevel {
  details,
  busy,
  invisible;

  static ShareLevel fromCode(String? code) =>
      values.firstWhere((level) => level.name == code, orElse: () => busy);
}

/// Un groupe dont l'utilisateur est membre, avec son rôle et son partage.
final class MyGroup {
  const MyGroup({
    required this.id,
    required this.name,
    required this.role,
    required this.shareLevel,
    this.description,
  });

  final String id;
  final String name;
  final String? description;
  final GroupRole role;
  final ShareLevel shareLevel;
}

final class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.shareLevel,
    required this.isMe,
  });

  final String userId;
  final String displayName;
  final GroupRole role;
  final ShareLevel shareLevel;

  /// L'utilisateur lui-même.
  final bool isMe;
}

/// Une invitation : son code (le secret) et sa date d'expiration.
final class GroupInvite {
  const GroupInvite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

/// Ce qu'un code valide laisse voir avant de rejoindre.
final class InvitePreview {
  const InvitePreview({
    required this.groupId,
    required this.name,
    required this.memberCount,
    required this.isMember,
  });

  final String groupId;
  final String name;
  final int memberCount;
  final bool isMember;
}
