import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/resolve_chat_title.dart';
import '../../domain/value_objects/chat_group_avatar.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../../domain/value_objects/chat_role.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_avatar.dart';

// Moved to the domain (storage counts videos too); kept reachable here for
// the widgets that already import labels.
export '../../domain/value_objects/chat_media_kind.dart'
    show isVideoFile, isVideoName;

/// `[@Display Name](@#userId)` — how xxd encodes a mention inside text.
final chatMentionPattern = RegExp(r'\[@([^\]]+)\]\(@#(\d+)\)');

/// A mention (group `mention` = the name) or a web address, for rendering
/// plain text.
final chatTokenPattern = RegExp(
  r'\[@(?<mention>[^\]]+)\]\(@#(?<mentionId>\d+)\)|' + _urlPattern,
);

/// The user id of a mention link target (`@#24`), else null.
int? chatMentionUserId(String url) {
  final m = RegExp(r'^@#(\d+)$').firstMatch(url.trim());
  return m == null ? null : int.parse(m[1]!);
}

/// A web address, without trailing punctuation that ends the sentence.
const _urlPattern =
    r'https?://[^\s<>()]+[^\s<>().,;:!?'
    "'"
    r'"]';

/// First web address in a text, for a link preview.
String? chatFirstUrl(String text) => RegExp(_urlPattern).firstMatch(text)?[0];

/// Every web address in [text], in order, without repeats.
List<String> chatUrls(String text) =>
    {for (final m in RegExp(_urlPattern).allMatches(text)) m[0]!}.toList();

/// Whether plain text is evidently Markdown — people paste it into `plain`
/// messages too — so it can be rendered formatted.
bool chatLooksLikeMarkdown(String text) => _markdownSignal.hasMatch(text);

final _markdownSignal = RegExp(
  r'^\s{0,3}(#{1,6}\s|[-*+]\s+\S|\d+\.\s+\S|>\s|```|\|.*\|)'
  r'|\*\*[^*\n]+\*\*|__[^_\n]+__|`[^`\n]+`|~~[^~\n]+~~'
  r'|\[[^\]@][^\]]*\]\(https?://',
  multiLine: true,
);

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

/// One-line preview of a message for the chat list.
String chatPreview(BuildContext context, ChatMessage message) {
  final l = AppL10n.of(context);
  // A retracted message keeps no content; say so rather than show nothing.
  if (message.deleted) return l.chatRetracted;
  return switch (message.content) {
    TextContent(:final text, :final markdown) =>
      (markdown ? _stripMarkdown(text) : text)
          .replaceAllMapped(chatMentionPattern, (m) => '@${m[1]}')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
    EmojiContent(:final emoji) => emoji,
    NotificationContent(:final title, :final text) =>
      (title ?? _stripMarkdown(text)).replaceAll(RegExp(r'\s+'), ' ').trim(),
    ImageContent() => l.chatImage,
    FileContent(:final name) => '${l.chatFile}: $name',
    LinkContent(:final title, :final url) => title ?? url,
    UnsupportedContent(:final contentType) => l.chatUnsupportedMessage(
      contentType,
    ),
  };
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
String formatTransfer(int bytes, double? progress) => progress == null
    ? formatFileSize(bytes)
    : '${formatFileSize((bytes * progress.clamp(0, 1)).round())} / '
          '${formatFileSize(bytes)}';

/// A user's avatar URL, when they have one.
String? chatAvatarUrl(Map<int, ChatUser> users, int? id) =>
    id == null ? null : users[id]?.avatarUrl;

/// Day separator label: today / yesterday / a localized date.
String chatDayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final l = AppL10n.of(context);
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final d = DateUtils.dateOnly(day);
  if (d == today) return l.chatToday;
  if (d == today.subtract(const Duration(days: 1))) return l.chatYesterday;
  final locale = Localizations.localeOf(context).toString();
  return d.year == today.year
      ? DateFormat.MMMMd(locale).format(d)
      : DateFormat.yMMMMd(locale).format(d);
}

/// Compact time for the chat list: 10:05 today, "Yesterday", a weekday within
/// the week, else a short date.
String chatListTime(BuildContext context, DateTime? t, {DateTime? now}) {
  if (t == null) return '';
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(t);
  final locale = Localizations.localeOf(context).toString();
  final age = today.difference(day).inDays;
  if (age == 0) return DateFormat('HH:mm').format(t);
  if (age == 1) return AppL10n.of(context).chatYesterday;
  if (age < 7) return DateFormat.E(locale).format(t);
  return t.year == today.year
      ? DateFormat('dd/MM').format(t)
      : DateFormat('dd/MM/yy').format(t);
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

/// Markdown reduced to its words for one-line previews: code fences, list
/// and heading markers, emphasis and plain link syntax are dropped (mention
/// links are kept for [chatMentionPattern]).
String _stripMarkdown(String text) => text
    .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
    .replaceAll(
      RegExp(r'^\s{0,3}(#{1,6}|[-*+]|\d+\.|>)\s+', multiLine: true),
      '',
    )
    .replaceAllMapped(
      RegExp(r'\[([^\]@][^\]]*)\]\((?!@#)[^)]*\)'),
      (m) => m[1]!,
    )
    .replaceAll(RegExp(r'(\*\*|__|\*|~~|`)'), '');

/// How a chat's avatar is drawn: a picture, or a text on a colour (groups
/// that set one); null fields fall back to the title's initials.
({String? imageUrl, String? label, Color? background}) chatAvatarStyle(
  ChatConversation chat,
  Map<int, ChatUser> users,
) {
  if (chat.type == ChatType.one2one) {
    return (
      imageUrl: chatAvatarUrl(users, chat.peerUserId),
      label: null,
      background: null,
    );
  }
  return switch (ChatGroupAvatar.fromJson(chat.avatarJson)) {
    ChatImageAvatar(:final url) => (
      imageUrl: url,
      label: null,
      background: null,
    ),
    ChatTextAvatar(:final text, :final color) => (
      imageUrl: null,
      label: text,
      background: chatHexColor(color),
    ),
    null => (imageUrl: null, label: null, background: null),
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

/// A ZenTao role's official name; an admin-defined code stays as it is.
String chatRoleLabel(BuildContext context, String role) {
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
    null => role,
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
  final role = ChatRole.fromCode(users[id]?.role);
  final rank = role?.rank;
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

/// How long ago [t] was, compactly: "just now", "5m ago", "2h ago", "3d
/// ago", then the date.
String chatAgo(BuildContext context, DateTime t, {DateTime? now}) {
  final l = AppL10n.of(context);
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return l.justNow;
  if (diff.inHours < 1) return l.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l.hoursAgo(diff.inHours);
  if (diff.inDays < 30) return l.daysAgo(diff.inDays);
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(t);
}
