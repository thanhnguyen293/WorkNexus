import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/value_objects/chat_presence.dart';
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
    required this.avatar,
    this.presence,
    this.verified,
    this.lastSender,
    this.compact = false,
  });

  /// Avatar only (with the unread count on it), the title as a tooltip —
  /// for the collapsed chat list.
  final bool compact;

  final ChatConversation chat;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  /// See `chatAvatarStyle`.
  final ({String? imageUrl, String? label, Color? background}) avatar;

  /// The other person's presence (one-to-one chats).
  final ChatPresence? presence;

  /// The other person's "verified" check (one-to-one chats, leading roles).
  final ChatVerifiedBadge? verified;

  /// Who sent the last message, shown before its preview (groups).
  final String? lastSender;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final last = chat.lastMessage;
    final unread = chat.unreadCount > 0;
    final avatarWidget = ChatAvatar(
      name: title,
      imageUrl: avatar.imageUrl,
      label: avatar.label,
      background: avatar.background,
      presence: presence,
      verified: verified,
    );
    if (compact) {
      return Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: context.spacing.md),
            color: selected ? c.selectionFill : Colors.transparent,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  avatarWidget,
                  if (unread)
                    Positioned(
                      top: -context.spacing.xs,
                      right: -context.spacing.sm,
                      child: UnreadBadge(count: chat.unreadCount),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // Square and edge to edge: the selection fills the whole row; the inner
    // margin keeps the content where the list's own used to put it.
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.xl3,
          vertical: context.spacing.md,
        ),
        color: selected ? c.selectionFill : Colors.transparent,
        child: Row(
          children: [
            avatarWidget,
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
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (lastSender case final sender?)
                                TextSpan(
                                  text: '$sender: ',
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              TextSpan(
                                text: last == null
                                    ? ''
                                    : chatPreview(context, last),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.bodySm.copyWith(
                            color: unread ? c.textPrimary : c.textSecondary,
                          ),
                        ),
                      ),
                      if (chat.muted) ...[
                        SizedBox(width: context.spacing.sm),
                        Icon(
                          PhosphorIconsLight.bellSlash,
                          size: context.spacing.xl2,
                          color: c.textTertiary,
                        ),
                      ],
                      if (chat.starred) ...[
                        SizedBox(width: context.spacing.sm),
                        Icon(
                          PhosphorIconsFill.pushPin,
                          size: context.spacing.xl2,
                          color: c.textTertiary,
                        ),
                      ],
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
