import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/contrast.dart';
import '../../../../core/widgets/hover_surface.dart';
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
    this.senderColor,
  });

  final ChatThreadKey chat;
  final int replyToId;
  final Map<int, ChatUser> users;
  final VoidCallback onTap;

  /// When set, the quote takes the quoted sender's colour for its bar, tint
  /// and name (Telegram) instead of the bubble's quote ink.
  final Color Function(int senderId)? senderColor;

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
    final accent = switch ((message, widget.senderColor)) {
      (final m?, final colorOf?) => colorOf(m.senderId),
      _ => null,
    };
    final bar = accent ?? ink.quoteBar;
    final fill = accent?.withValues(alpha: 0.12) ?? ink.quoteFill;
    final label = context.typography.caption.copyWith(fontSize: ink.labelSize);
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: HoverSurface(
        onTap: widget.onTap,
        padding: EdgeInsets.fromLTRB(
          context.spacing.lg,
          context.spacing.sm,
          context.spacing.lg,
          context.spacing.sm,
        ),
        color: fill,
        hoverColor: ink.hoverFill,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border(left: BorderSide(color: bar, width: 3)),
        child: message == null
            ? Text(
                l.chatReplyMissing,
                style: label.copyWith(color: c.textTertiary),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatUserName(context, widget.users, message.senderId),
                    style: label.copyWith(
                      fontWeight: ink.labelSize == null
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: readableOn(
                        bar,
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
                    style: label.copyWith(color: ink.text),
                  ),
                ],
              ),
      ),
    );
  }
}
