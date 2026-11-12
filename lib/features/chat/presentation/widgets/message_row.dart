import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import 'bubble_tail.dart';
import 'chat_style.dart';

/// A message laid out beside its sender's avatar column: [avatar] on the
/// start side, or on the end side for [alignEnd], when there is one. With
/// [name] the sender's name goes over the avatar and bubble together, so
/// the avatar lines up with the bubble; it is indented to the bubble's edge
/// (past the avatar and the tail's room).
class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.avatar,
    required this.alignEnd,
    required this.style,
    required this.top,
    required this.child,
    this.name,
  });

  final Widget? avatar;
  final bool alignEnd;

  /// The chat style: avatar size and placement, and the tail's room.
  final ChatStyle style;

  /// The gap above the row.
  final double top;
  final Widget child;
  final Widget? name;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final gap = s.md;
    final avatar = this.avatar;
    final row = Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      // The avatar sits by the run's last bubble (Telegram) or its first.
      crossAxisAlignment: style.avatar == ChatAvatarPlacement.lastOfRun
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (avatar != null && !alignEnd) ...[avatar, SizedBox(width: gap)],
        Flexible(child: child),
        if (avatar != null && alignEnd) ...[SizedBox(width: gap), avatar],
      ],
    );
    final name = this.name;
    final tailRoom = style.tail == null ? 0.0 : BubbleTail.width;
    final indent = tailRoom + (avatar != null ? style.avatarSize + gap : 0);
    if (name == null) {
      return Padding(
        padding: EdgeInsets.only(top: top),
        child: row,
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: alignEnd ? 0 : indent,
              right: alignEnd ? indent : 0,
              bottom: s.xs,
            ),
            child: name,
          ),
          row,
        ],
      ),
    );
  }
}
