import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../providers/chat_providers.dart';
import 'chat_labels.dart';

/// Above the composer input: which message is being replied to — sender and
/// a one-line preview — with a button to cancel the reply.
class ReplyDraftBanner extends ConsumerWidget {
  const ReplyDraftBanner({
    super.key,
    required this.message,
    required this.accountId,
    required this.onCancel,
  });

  final ChatMessage message;
  final String accountId;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final users =
        ref.watch(chatUsersProvider(accountId)).asData?.value ??
        const <int, ChatUser>{};
    final name = message.isMine && !users.containsKey(message.senderId)
        ? l.chatYou
        : chatUserName(context, users, message.senderId);
    final caption = context.typography.caption.copyWith(color: c.textSecondary);
    return Container(
      margin: EdgeInsets.fromLTRB(s.xs, s.xs, s.xs, 0),
      padding: EdgeInsets.fromLTRB(s.lg, s.sm, s.xs, s.sm),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote_rounded, size: s.xl2, color: c.accent),
          SizedBox(width: s.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '${l.chatReplyingTo} ',
                    children: [
                      TextSpan(
                        text: name,
                        style: context.typography.captionStrong.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caption,
                ),
                Text(
                  message.deleted
                      ? l.chatRetracted
                      : chatPreview(context, message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySm.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l.chatCancelReply,
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
