import 'package:flutter/material.dart';

import '../../domain/entities/chat_user.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_profile_tap.dart';
import 'chat_style.dart';

/// The column beside a run of messages that holds the sender's avatar: as
/// wide as the avatar on every message, so bubbles line up, with the avatar
/// itself only where the style puts it ([visible]).
class MessageAvatarSlot extends StatelessWidget {
  const MessageAvatarSlot({
    super.key,
    required this.accountId,
    required this.senderId,
    required this.name,
    required this.users,
    required this.style,
    required this.visible,
  });

  final String accountId;
  final int senderId;
  final String name;
  final Map<int, ChatUser> users;
  final ChatStyle style;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: style.avatarSize,
      child: visible
          ? ChatProfileTap(
              accountId: accountId,
              userId: senderId,
              name: name,
              child: ChatAvatar(
                name: name,
                imageUrl: chatAvatarUrl(users, senderId),
                verified: chatVerifiedBadge(context, users, senderId),
                shape: style.avatarShape,
                diameter: style.avatarSize,
              ),
            )
          : null,
    );
  }
}
