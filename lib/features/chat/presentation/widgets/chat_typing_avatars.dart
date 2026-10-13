import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/chat_user.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_style.dart';

/// The typing bubble's avatar slot: the first person typing, sized and shaped
/// like the avatars beside received messages.
class ChatTypingAvatar extends StatelessWidget {
  const ChatTypingAvatar({
    super.key,
    required this.style,
    required this.users,
    required this.userId,
  });

  final ChatStyle style;
  final Map<int, ChatUser> users;
  final int userId;

  @override
  Widget build(BuildContext context) => ChatAvatar(
    name: chatUserName(context, users, userId),
    imageUrl: chatAvatarUrl(users, userId),
    shape: style.avatarShape,
    diameter: style.avatarSize,
  );
}

/// How many of the others typing get a face; the rest are counted.
const int _kMaxFaces = 3;

/// Everyone else typing, as small overlapping faces after the bubble, then
/// "+N" for those beyond [_kMaxFaces].
class ChatTypingOthers extends StatelessWidget {
  const ChatTypingOthers({super.key, required this.users, required this.ids});

  final Map<int, ChatUser> users;
  final List<int> ids;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final face = context.sizes.iconLg;
    // Each face covers part of the one before; the ring keeps them apart.
    final ring = context.spacing.xxs;
    final step = face * 0.65;
    final faces = ids.take(_kMaxFaces).toList();
    final rest = ids.length - faces.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: step * (faces.length - 1) + face + ring * 2,
          height: face + ring * 2,
          child: Stack(
            children: [
              for (final (i, id) in faces.indexed)
                Positioned(
                  left: step * i,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(ring),
                      child: ChatAvatar(
                        name: chatUserName(context, users, id),
                        imageUrl: chatAvatarUrl(users, id),
                        diameter: face,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (rest > 0) ...[
          SizedBox(width: s.xs),
          Text(
            '+$rest',
            style: context.typography.captionSm.copyWith(
              color: c.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
