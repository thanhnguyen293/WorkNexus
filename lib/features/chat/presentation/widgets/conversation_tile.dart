import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_conversation.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'unread_badge.dart';

/// One row of the chat list: avatar, title, last message, time and unread.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.chat,
    required this.title,
    required this.selected,
    required this.onTap,
    this.avatarUrl,
  });

  final ChatConversation chat;
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = chat.lastMessage;
    final unread = chat.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Container(
        padding: EdgeInsets.all(context.spacing.md),
        decoration: BoxDecoration(
          color: selected ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Row(
          children: [
            ChatAvatar(name: title, imageUrl: avatarUrl),
            SizedBox(width: context.spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.body.copyWith(
                            color: c.textPrimary,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        chatListTime(context, chat.lastActiveAt),
                        style: context.typography.captionSm.copyWith(
                          color: unread ? c.accent : c.textTertiary,
                          fontWeight: unread ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.spacing.xxs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last == null ? '' : chatPreview(context, last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.bodySm.copyWith(
                            color: unread ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        SizedBox(width: context.spacing.sm),
                        UnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
