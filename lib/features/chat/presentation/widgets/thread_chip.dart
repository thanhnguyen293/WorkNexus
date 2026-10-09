import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/usecases/build_reply_thread.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';

/// Under a thread's root message: who replied (overlapping avatars), how many
/// replies and when the last one came. Opens the thread.
class ThreadChip extends StatelessWidget {
  const ThreadChip({
    super.key,
    required this.summary,
    required this.users,
    required this.onTap,
  });

  final ThreadSummary summary;
  final Map<int, ChatUser> users;
  final VoidCallback onTap;

  static const _maxFaces = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final faces = summary.replierIds.take(_maxFaces).toList();
    final face = s.xl5;
    final step = face * 0.62;
    return Material(
      color: c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.border)),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(s.xs, s.xs, s.xl, s.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: face + step * (faces.length - 1),
                height: face,
                child: Stack(
                  children: [
                    for (final (i, id) in faces.indexed)
                      Positioned(
                        left: step * i,
                        child: DecoratedBox(
                          // Ring in the chip colour separates the faces.
                          decoration: ShapeDecoration(
                            shape: CircleBorder(
                              side: BorderSide(color: c.surface, width: 2),
                            ),
                          ),
                          child: ChatAvatar(
                            name: chatUserName(context, users, id),
                            imageUrl: chatAvatarUrl(users, id),
                            size: ChatAvatarSize.small,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: s.md),
              Text(
                l.chatReplies(summary.count),
                style: context.typography.captionStrong.copyWith(
                  color: c.accent,
                ),
              ),
              SizedBox(width: s.md),
              Text(
                chatListTime(context, summary.lastReplyAt),
                style: context.typography.caption.copyWith(
                  color: c.textTertiary,
                ),
              ),
              SizedBox(width: s.xs),
              Icon(
                PhosphorIconsLight.caretRight,
                size: s.xl3,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
