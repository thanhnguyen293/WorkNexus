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

part 'chat_labels_files.dart';
part 'chat_labels_people.dart';
part 'chat_labels_time.dart';

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

/// The host of a URL, for link cards.
String chatLinkHost(String url) => Uri.tryParse(url)?.host ?? url;

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
