part of 'chat_labels.dart';

// People helpers: chat titles, names, initials, avatars, presence and roles.

/// A conversation's title, with a localized fallback.
String chatTitle(
  BuildContext context,
  ChatConversation chat,
  Map<int, ChatUser> users,
) {
  final resolved = const ResolveChatTitle()(chat, users);
  if (resolved != null) return resolved;
  final peer = chat.peerUserId;
  final l = AppL10n.of(context);
  return peer != null ? l.chatUnknownUser(peer) : l.chatUntitled;
}

/// A user's display name, with a localized fallback.
String chatUserName(BuildContext context, Map<int, ChatUser> users, int id) {
  final u = users[id];
  // xxd's bot (xuanbot replies, ZenTao notifications) is user 0.
  if (id == 0) return AppL10n.of(context).chatBotName;
  if (u == null) return AppL10n.of(context).chatUnknownUser(id);
  return u.realname.isNotEmpty ? u.realname : u.account;
}

/// Up to two initials for an avatar.
String chatInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s_\-]+'))
      .where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w.characters.first.toUpperCase());
  final joined = letters.join();
  return joined.isEmpty ? '?' : joined;
}

/// A user's avatar URL, when they have one.
String? chatAvatarUrl(Map<int, ChatUser> users, int? id) =>
    id == null ? null : users[id]?.avatarUrl;

/// `#RRGGBB` from the server (a user's chosen group colour) as a [Color].
Color? chatHexColor(String hex) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  if (v == null || hex.replaceFirst('#', '').length != 6) return null;
  return Color(0xFF000000 | v);
}

/// A user's presence (null when unknown).
ChatPresence? chatPresenceOf(Map<int, ChatUser> users, int? id) {
  final status = users[id]?.status;
  return status == null ? null : ChatPresence.fromStatus(status);
}

/// Names for role codes admins often add beyond ZenTao's defaults, which
/// the server sends no name for.
String? _extraRoleName(AppL10n l, String code) => switch (code.toLowerCase()) {
  'ui' || 'designer' => l.chatRoleUi,
  'ux' => l.chatRoleUx,
  'op' || 'ops' => l.chatRoleOp,
  'opm' => l.chatRoleOpm,
  'ba' => l.chatRoleBa,
  'devops' => l.chatRoleDevops,
  _ => null,
};

/// A ZenTao role's official name. A role an admin added takes a name of ours
/// for common codes (`ui` → Designer), else the server's ([serverNames],
/// code → name), else stays as its code.
String chatRoleLabel(
  BuildContext context,
  String role, {
  Map<String, String> serverNames = const {},
}) {
  final l = AppL10n.of(context);
  return switch (ChatRole.fromCode(role)) {
    ChatRole.dev => l.chatRoleDev,
    ChatRole.qa => l.chatRoleQa,
    ChatRole.pm => l.chatRolePm,
    ChatRole.po => l.chatRolePo,
    ChatRole.td => l.chatRoleTd,
    ChatRole.pd => l.chatRolePd,
    ChatRole.qd => l.chatRoleQd,
    ChatRole.top => l.chatRoleTop,
    ChatRole.others => l.chatRoleOthers,
    null => _extraRoleName(l, role.trim()) ?? serverNames[role.trim()] ?? role,
  };
}

/// The "verified" check beside a user's avatar — the colour of their rank
/// and their role, for the legend shown on hover; null for engineers,
/// "others" and unknown roles.
ChatVerifiedBadge? chatVerifiedBadge(
  BuildContext context,
  Map<int, ChatUser> users,
  int? id,
) {
  final role = users[id]?.role?.trim();
  final rank = chatRoleRankOf(role);
  if (role == null || rank == null) return null;
  return (color: chatRankColor(context, rank), role: role);
}

/// The "verified" check colour of a rank.
Color chatRankColor(BuildContext context, ChatRoleRank rank) {
  final c = context.colors;
  return switch (rank) {
    ChatRoleRank.lead => c.verifiedLead,
    ChatRoleRank.manager => c.verifiedManager,
    ChatRoleRank.executive => c.verifiedExecutive,
  };
}

/// "Online", "Away", "Busy" or "Offline".
String chatPresenceLabel(BuildContext context, ChatPresence presence) {
  final l = AppL10n.of(context);
  return switch (presence) {
    ChatPresence.online => l.chatOnline,
    ChatPresence.away => l.chatAway,
    ChatPresence.busy => l.chatBusy,
    ChatPresence.offline => l.chatOffline,
  };
}
