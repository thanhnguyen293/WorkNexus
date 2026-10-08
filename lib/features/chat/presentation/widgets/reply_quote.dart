import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/contrast.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_bubble_theme.dart';
import 'chat_labels.dart';

/// The message a reply answers, quoted above the reply. Fetches it from the
/// server when it is older than what is loaded. Tap jumps to it in the chat.
class ReplyQuote extends ConsumerStatefulWidget {
  const ReplyQuote({
    super.key,
    required this.chat,
    required this.replyToId,
    required this.users,
    required this.onTap,
  });

  final ChatThreadKey chat;
  final int replyToId;
  final Map<int, ChatUser> users;
  final VoidCallback onTap;

  @override
  ConsumerState<ReplyQuote> createState() => _ReplyQuoteState();
}

class _ReplyQuoteState extends ConsumerState<ReplyQuote> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = ChatBubbleTheme.of(context);
    final l = AppL10n.of(context);
    final key = (chat: widget.chat, serverId: widget.replyToId);
    final original = ref.watch(chatMessageByIdProvider(key));
    if (original case AsyncData(value: null) when !_requested) {
      _requested = true;
      ref.read(chatControllerProvider).fetchMessages(
        widget.chat.accountId,
        widget.chat.chatGid,
        [widget.replyToId],
      );
    }
    final message = original.asData?.value;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        margin: EdgeInsets.only(bottom: context.spacing.md),
        padding: EdgeInsets.fromLTRB(
          context.spacing.lg,
          context.spacing.sm,
          context.spacing.lg,
          context.spacing.sm,
        ),
        decoration: BoxDecoration(
          color: ink.quoteFill,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: Border(left: BorderSide(color: ink.quoteBar, width: 3)),
        ),
        child: message == null
            ? Text(
                l.chatReplyMissing,
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatUserName(context, widget.users, message.senderId),
                    style: context.typography.captionStrong.copyWith(
                      color: readableOn(
                        ink.quoteBar,
                        ink.quoteSurface,
                        towards: ink.text,
                      ),
                    ),
                  ),
                  Text(
                    message.deleted
                        ? l.chatRetracted
                        : chatPreview(context, message),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(color: ink.text),
                  ),
                ],
              ),
      ),
    );
  }
}
