import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/resolve_chat_title.dart';
import '../../domain/value_objects/chat_group_avatar.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../../domain/value_objects/chat_role.dart';
import 'chat_avatar.dart';

// Moved to the domain (storage counts videos too); kept reachable here for
// the widgets that already import labels.
export '../../domain/value_objects/chat_media_kind.dart'
    show isVideoFile, isVideoName;

// The text helpers (mentions, addresses, Markdown, previews) live beside.
export 'chat_text_labels.dart';

final _nameSeparators = RegExp(r'[\s_\-]+');

/// A conversation's title, with a localized fallback.
String chatTitle(
  BuildContext context,
  ChatConversation chat,
  Map<int, ChatUser> users,
) {
  if (chat.isMyCloud) return AppL10n.of(context).chatMyCloud;
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
  final words = name.trim().split(_nameSeparators).where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => w.characters.first.toUpperCase());
  final joined = letters.join();
  return joined.isEmpty ? '?' : joined;
}

/// Whether a file to send is an image (gets a thumbnail in the preview).
bool isImageAttachment(String name) => const {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
}.contains(_extension(name));

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// Human-readable byte size.
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    final gb = bytes / 1024 / 1024 / 1024;
    // Whole sizes (limits like 2 GB) read better without ".0".
    return '${gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

/// A file's size, or — while it transfers ([progress] 0–1) — how much of it
/// has moved: `12.3 MB / 364.2 MB`.
String formatTransfer(int bytes, double? progress) {
  if (progress == null) return formatFileSize(bytes);
  final p = progress.clamp(0, 1);
  return '${formatPercent(p)} · '
      '${formatFileSize((bytes * p).round())} / ${formatFileSize(bytes)}';
}

/// A transfer's progress (0–1) as a whole percentage (`0.456` → `46%`).
String formatPercent(num progress) =>
    '${(progress.clamp(0, 1) * 100).round()}%';

/// A user's avatar URL, when they have one.
String? chatAvatarUrl(Map<int, ChatUser> users, int? id) =>
    id == null ? null : users[id]?.avatarUrl;

/// Day separator label: today / yesterday / a localized date.
String chatDayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final l = AppL10n.of(context);
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final localDay = day.toLocal();
  final d = DateUtils.dateOnly(localDay);
  if (d == today) return l.chatToday;
  if (d == today.subtract(const Duration(days: 1))) return l.chatYesterday;
  final locale = Localizations.localeOf(context).toString();
  return d.year == today.year
      ? DateFormat.MMMMd(locale).format(d)
      : DateFormat.yMMMMd(locale).format(d);
}

/// Compact time for the chat list: 10:05 today, "Yesterday", a weekday within
/// the week, else a short date. Always rendered in user local time.
String chatListTime(BuildContext context, DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final local = t.toLocal();
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(local);
  final locale = Localizations.localeOf(context).toString();
  final age = today.difference(day).inDays;
  if (age == 0) return DateFormat('HH:mm').format(local);
  if (age == 1) return AppL10n.of(context).chatYesterday;
  if (age < 7) return DateFormat.E(locale).format(local);
  return local.year == today.year
      ? DateFormat('dd/MM').format(local)
      : DateFormat('dd/MM/yy').format(local);
}

/// The host of a URL, for link cards.
String chatLinkHost(String url) => Uri.tryParse(url)?.host ?? url;

/// Upper-case file extension for the file tile badge (max 4 chars).
String chatFileBadge(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return 'FILE';
  final ext = name.substring(dot + 1).toUpperCase();
  return ext.length > 4 ? ext.substring(0, 4) : ext;
}

/// How a chat's avatar is drawn: a picture, a text on a colour (groups
/// that set one) or a glyph (My Cloud); null fields fall back to the title's
/// initials.
typedef ChatAvatarStyle = ({
  String? imageUrl,
  String? label,
  Color? background,
  IconData? icon,
});

ChatAvatarStyle chatAvatarStyle(
  ChatConversation chat,
  Map<int, ChatUser> users,
) {
  if (chat.isMyCloud) {
    return (
      imageUrl: null,
      label: null,
      background: null,
      icon: LucideIcons.cloud300,
    );
  }
  if (chat.type == ChatType.one2one) {
    return (
      imageUrl: chatAvatarUrl(users, chat.peerUserId),
      label: null,
      background: null,
      icon: null,
    );
  }
  return switch (ChatGroupAvatar.fromJson(chat.avatarJson)) {
    ChatImageAvatar(:final url) => (
      imageUrl: url,
      label: null,
      background: null,
      icon: null,
    ),
    ChatTextAvatar(:final text, :final color) => (
      imageUrl: null,
      label: text,
      background: chatHexColor(color),
      icon: null,
    ),
    null => (imageUrl: null, label: null, background: null, icon: null),
  };
}

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
  final trimmed = role.trim();
  return switch (ChatRole.fromCode(trimmed)) {
    ChatRole.dev => l.chatRoleDev,
    ChatRole.qa => l.chatRoleQa,
    ChatRole.pm => l.chatRolePm,
    ChatRole.po => l.chatRolePo,
    ChatRole.td => l.chatRoleTd,
    ChatRole.pd => l.chatRolePd,
    ChatRole.qd => l.chatRoleQd,
    ChatRole.top => l.chatRoleTop,
    ChatRole.others => l.chatRoleOthers,
    null => _extraRoleName(l, trimmed) ?? serverNames[trimmed] ?? role,
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

/// "Online", "Away", "Busy", "In meeting" or "Offline".
String chatPresenceLabel(BuildContext context, ChatPresence presence) {
  final l = AppL10n.of(context);
  return switch (presence) {
    ChatPresence.online => l.chatOnline,
    ChatPresence.away => l.chatAway,
    ChatPresence.busy => l.chatBusy,
    ChatPresence.meeting => l.chatInMeeting,
    ChatPresence.offline => l.chatOffline,
  };
}

/// How long ago [t] was, compactly: "just now", "5m ago", "2h ago", "3d
/// ago", then the date. Always rendered in user local time.
String chatAgo(BuildContext context, DateTime t, {DateTime? now}) {
  final l = AppL10n.of(context);
  final local = t.toLocal();
  final diff = (now ?? DateTime.now()).difference(local);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 30) return l.daysAgo(diff.inDays);
  return DateFormat.yMMMd(
    Localizations.localeOf(context).toString(),
  ).format(local);
}
