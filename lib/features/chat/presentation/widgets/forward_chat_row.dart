import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'chat_avatar.dart';
import 'chat_labels.dart';
import 'chat_pick_tick.dart';

/// A chat to forward to: avatar, title and a round tick; picked rows are
/// tinted, like the people picker of a new chat.
class ForwardChatRow extends StatelessWidget {
  const ForwardChatRow({
    super.key,
    required this.title,
    required this.avatar,
    required this.picked,
    required this.onTap,
  });

  final String title;
  final ChatAvatarStyle avatar;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.md);
    return Material(
      color: picked ? c.selectionFill : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.sm),
          child: Row(
            children: [
              ChatAvatar(
                name: title,
                imageUrl: avatar.imageUrl,
                label: avatar.label,
                background: avatar.background,
                icon: avatar.icon,
              ),
              SizedBox(width: s.lg),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              ChatPickTick(picked: picked),
            ],
          ),
        ),
      ),
    );
  }
}
