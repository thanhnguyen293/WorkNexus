import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// A message laid out beside its sender's avatar column: [avatar] on the
/// start side, or on the end side for [alignEnd], when there is one. With
/// [name] the sender's name goes over the avatar and bubble together, so
/// the avatar lines up with the bubble; it starts at the row's edge, over
/// the avatar.
class MessageRow extends StatelessWidget {
  const MessageRow({
    super.key,
    required this.avatar,
    required this.alignEnd,
    required this.avatarAtBottom,
    required this.top,
    required this.child,
    this.name,
  });

  final Widget? avatar;
  final bool alignEnd;

  /// The avatar sits by the run's last bubble (Telegram), not its first.
  final bool avatarAtBottom;

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
      crossAxisAlignment: avatarAtBottom
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (avatar != null && !alignEnd) ...[avatar, SizedBox(width: gap)],
        Flexible(child: child),
        if (avatar != null && alignEnd) ...[SizedBox(width: gap), avatar],
      ],
    );
    final name = this.name;
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
            padding: EdgeInsets.only(bottom: s.xs),
            child: name,
          ),
          row,
        ],
      ),
    );
  }
}
