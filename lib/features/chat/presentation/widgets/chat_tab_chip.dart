import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A filter chip of the chat's tab rows (chat list, role tabs): tinted
/// when [selected].
class ChatTabChip extends StatelessWidget {
  const ChatTabChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.md),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.md),
        ),
        child: Text(
          label,
          style: context.typography.secondary.copyWith(
            color: selected ? c.accent : c.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
