import 'package:flutter/widgets.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_message_reaction.dart';
import '../../domain/value_objects/message_content.dart';

/// Text helpers for chat: mentions, web addresses, Markdown detection and
/// one-line previews. Reachable through `chat_labels.dart` too.

/// `[@Display Name](@#userId)` — how xxd encodes a mention inside text.
final chatMentionPattern = RegExp(r'\[@([^\]]+)\]\(@#(\d+)\)');

/// A mention (group `mention` = the name) or a web address, for rendering
/// plain text.
final chatTokenPattern = RegExp(
  r'\[@(?<mention>[^\]]+)\]\(@#(?<mentionId>\d+)\)|' + _urlPattern,
);

/// The user id of a mention link target (`@#24`), else null.
int? chatMentionUserId(String url) {
  final m = _mentionLink.firstMatch(url.trim());
  return m == null ? null : int.parse(m[1]!);
}

/// A web address, without trailing punctuation that ends the sentence and
/// without the brackets of Markdown (`[text](url)`, `[url](url)`).
const _urlPattern =
    r'https?://[^\s<>()\[\]]+[^\s<>()\[\].,;:!?'
    "'"
    r'"]';

/// First web address in a text, for a link preview.
String? chatFirstUrl(String text) => _url.firstMatch(text)?[0];

/// Every web address in [text], in order, without repeats: one written twice
/// (as plain text and as a Markdown link, say) is one address, also when only
/// a trailing slash or a `#fragment` tells the two apart.
List<String> chatUrls(String text) {
  final seen = <String>{};
  return [
    for (final m in _url.allMatches(text))
      if (seen.add(_sameAddress(m[0]!))) m[0]!,
  ];
}

String _sameAddress(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final path = uri.path.endsWith('/') && uri.path.length > 1
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return '${uri.scheme}://${uri.authority.toLowerCase()}$path'
      '${uri.hasQuery ? '?${uri.query}' : ''}';
}

/// Whether plain text is evidently Markdown — people paste it into `plain`
/// messages too — so it can be rendered formatted.
bool chatLooksLikeMarkdown(String text) => _markdownSignal.hasMatch(text);

/// One-line preview of a message for the chat list.
String chatPreview(BuildContext context, ChatMessage message) {
  final l = AppL10n.of(context);
  // A retracted message keeps no content; say so rather than show nothing.
  if (message.deleted) return l.chatRetracted;
  if (message.reactionEmoji case final emoji?) return l.chatReacted(emoji);
  return switch (message.content) {
    TextContent(:final text, :final markdown) =>
      (markdown ? _stripMarkdown(text) : text)
          .replaceAllMapped(chatMentionPattern, (m) => '@${m[1]}')
          .replaceAll(_whitespace, ' ')
          .trim(),
    EmojiContent(:final emoji) => emoji,
    NotificationContent(:final title, :final text) =>
      (title ?? _stripMarkdown(text)).replaceAll(_whitespace, ' ').trim(),
    ImageContent() => l.chatImage,
    FileContent(:final name) => '${l.chatFile}: $name',
    LinkContent(:final title, :final url) => title ?? url,
    CodeContent(:final code, :final name) =>
      '${l.chatCode}: ${name ?? code.trim().split('\n').first.trim()}',
    UnsupportedContent(:final contentType) => l.chatUnsupportedMessage(
      contentType,
    ),
  };
}

/// The text of a server notice with its mentions kept: the server writes it
/// as Markdown (a chat name links to the chat, `_` comes escaped).
String chatNoticeText(TextContent content) => content.markdown
    ? _stripMarkdown(
        content.text,
      ).replaceAllMapped(_markdownEscape, (m) => m[1]!)
    : content.text;

/// Markdown reduced to its words for one-line previews: code fences, list
/// and heading markers, emphasis and plain link syntax are dropped (mention
/// links are kept for [chatMentionPattern]).
String _stripMarkdown(String text) => text
    .replaceAll(_codeFence, ' ')
    .replaceAll(_lineMarker, '')
    .replaceAllMapped(_plainLink, (m) => m[1]!)
    .replaceAll(_emphasis, '');

// Compiled once: these run per bubble and per chat row on every build.
final _mentionLink = RegExp(r'^@#(\d+)$');
final _url = RegExp(_urlPattern);
final _whitespace = RegExp(r'\s+');
final _markdownEscape = RegExp(r'\\([\\`*_{}\[\]()#+\-.!])');
final _codeFence = RegExp(r'```[\s\S]*?```');
final _lineMarker = RegExp(
  r'^\s{0,3}(#{1,6}|[-*+]|\d+\.|>)\s+',
  multiLine: true,
);
final _plainLink = RegExp(r'\[([^\]@][^\]]*)\]\((?!@#)[^)]*\)');
final _emphasis = RegExp(r'(\*\*|__|\*|~~|`)');
final _markdownSignal = RegExp(
  r'^\s{0,3}(#{1,6}\s|[-*+]\s+\S|\d+\.\s+\S|>\s|```|\|.*\|)'
  r'|\*\*[^*\n]+\*\*|__[^_\n]+__|`[^`\n]+`|~~[^~\n]+~~'
  r'|\[[^\]@][^\]]*\]\(https?://',
  multiLine: true,
);
