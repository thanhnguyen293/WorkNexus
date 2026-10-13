import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/unread_badge.dart';

/// A filter chip of the chat's tab rows (chat list, role tabs): tinted
/// when [selected], with an unread badge after the label when [unread] > 0.
class ChatTabChip extends StatelessWidget {
  const ChatTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.unread = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverSurface(
      onTap: onTap,
      selected: selected,
      height: context.sizes.controlSm,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
      color: selected ? c.selectionFill : null,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.typography.secondary.copyWith(
              color: selected ? c.accent : c.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (unread > 0) ...[
            SizedBox(width: context.spacing.sm),
            UnreadBadge(count: unread),
          ],
        ],
      ),
    );
  }
}
