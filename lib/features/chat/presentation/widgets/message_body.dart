import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
import 'link_preview_card.dart';
import 'mention_text.dart';

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
      TextContent(:final text, :final markdown) => _TextBody(
        accountId: accountId,
        text: text,
        markdown: markdown || chatLooksLikeMarkdown(text),
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
      LinkContent(:final url, :final title) => _LinkCard(
        url: url,
        title: title,
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

/// Message text — Markdown or plain with mentions and links — followed by a
/// preview of the first web page it links to.
class _TextBody extends ConsumerWidget {
  const _TextBody({
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
    final url = chatFirstUrl(text);
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
        if (url != null) LinkPreviewCard(url: url),
      ],
    );
  }
}

/// A shared link: icon tile, title and the site it points to.
class _LinkCard extends ConsumerWidget {
  const _LinkCard({required this.url, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = ChatBubbleTheme.of(context);
    final s = context.spacing;
    return InkWell(
      onTap: () => openChatLink(ref, url),
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: s.xl6,
            height: s.xl6,
            decoration: BoxDecoration(
              color: ink.tileFill,
              borderRadius: BorderRadius.circular(context.radii.md),
            ),
            child: Icon(Icons.link_rounded, color: ink.link),
          ),
          SizedBox(width: s.lg),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: ink.link,
                  ),
                ),
                Text(
                  chatLinkHost(url),
                  style: context.typography.caption.copyWith(color: ink.meta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
