import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/markdown_normalize.dart';
import '../../../../core/widgets/code_block.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/value_objects/message_content.dart';
import 'chat_bubble_theme.dart';
import 'chat_file_body.dart';
import 'chat_image_body.dart';
import 'chat_labels.dart';
import 'chat_links.dart';
import 'chat_user_profile_dialog.dart';
import 'mention_text.dart';
import 'notification_body.dart';

/// Whether a message renders as code or formatted Markdown — content that
/// reads better given more width than a chat line (code, tables, lists).
bool chatShowsWide(ChatMessage message) =>
    !message.deleted &&
    switch (message.content) {
      CodeContent() => true,
      final TextContent content => chatRendersMarkdownContent(content),
      _ => false,
    };

/// Many clients send everything as Markdown (`text`); a message without any
/// of its syntax skips the far costlier renderer. People also paste Markdown
/// into `plain`, so that is looked for too.
bool chatRendersMarkdown(String text, {required bool markdown}) =>
    (markdown || chatLooksLikeMarkdown(text)) && hasMarkdownSyntax(text);

/// [chatRendersMarkdown] for a message's content, decided once per content:
/// the two regex scans ran for every bubble on every build. Keyed by the
/// content object, which the repository keeps while its row is unchanged, so
/// the answer outlives rebuilds and goes away with the content.
bool chatRendersMarkdownContent(TextContent content) =>
    _rendersMarkdownOf[content] ??= chatRendersMarkdown(
      content.text,
      markdown: content.markdown,
    );

final _rendersMarkdownOf = Expando<bool>('rendersMarkdown');

/// The content of a message, by content type.
class MessageBody extends StatelessWidget {
  const MessageBody({
    super.key,
    required this.accountId,
    required this.message,
  });

  final String accountId;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ink = ChatBubbleTheme.of(context);
    final l = AppL10n.of(context);
    if (message.deleted) {
      return Text(
        l.chatRetracted,
        style: context.typography.body.copyWith(
          color: ink.meta,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return switch (message.content) {
      final TextContent content => ChatTextBody(
        accountId: accountId,
        text: content.text,
        markdown: chatRendersMarkdownContent(content),
      ),
      // Large, without a bubble (the bubble treats it as media).
      EmojiContent(:final emoji) => Text(
        emoji,
        style: context.typography.displayLg.copyWith(
          fontSize: context.spacing.xl6 * 1.5,
          height: 1.1,
        ),
      ),
      final NotificationContent notification => NotificationBody(
        accountId: accountId,
        notification: notification,
      ),
      final ImageContent image => ChatImageBody(
        accountId: accountId,
        message: message,
        image: image,
      ),
      final FileContent file => FileBody(
        accountId: accountId,
        message: message,
        file: file,
      ),
      // The link stays in the bubble; its preview shows under it.
      LinkContent(:final url, :final title) => ChatTextBody(
        accountId: accountId,
        text: title == null || title == url ? url : '$title\n$url',
        markdown: false,
      ),
      CodeContent(:final code, :final name) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (name != null) ...[
            Text(
              name,
              style: context.typography.bodySm.copyWith(color: ink.meta),
            ),
            SizedBox(height: context.spacing.xs),
          ],
          CodeBlock(code, fontSize: ink.fontSize - 1, collapsedLines: 10),
        ],
      ),
      UnsupportedContent(:final contentType) => Text(
        l.chatUnsupportedMessage(contentType),
        style: context.typography.bodySm.copyWith(
          color: ink.meta,
          fontStyle: FontStyle.italic,
        ),
      ),
    };
  }
}

/// Message text — Markdown or plain with mentions and links. Link previews
/// show under the bubble (`MessageLinkPreviews`).
class ChatTextBody extends ConsumerWidget {
  const ChatTextBody({
    super.key,
    required this.accountId,
    required this.text,
    required this.markdown,
  });

  final String accountId;
  final String text;

  /// Render through the Markdown engine (see [chatRendersMarkdown]); plain
  /// text otherwise.
  final bool markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = ChatBubbleTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (markdown)
          MarkdownText(
            text,
            fontSize: ink.fontSize,
            height: 1.5,
            color: ink.text,
            linkColor: ink.link,
            isPlainLink: (link) => chatMentionUserId(link) != null,
            onLinkTap: (link) => switch (chatMentionUserId(link)) {
              final userId? => ChatUserProfileDialog.show(
                context,
                accountId: accountId,
                userId: userId,
              ),
              null => openChatLink(ref, link),
            },
          )
        else
          MentionText(text, accountId: accountId),
      ],
    );
  }
}
