import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/markdown_normalize.dart';
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
      TextContent(:final text, :final markdown) => ChatTextBody(
        accountId: accountId,
        text: text,
        markdown: markdown || chatLooksLikeMarkdown(text),
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
  final bool markdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = ChatBubbleTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Many clients send everything as Markdown (`text`); a message
        // without any of its syntax skips the far costlier renderer.
        if (markdown && hasMarkdownSyntax(text))
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
