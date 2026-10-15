import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

class WorkspaceColorChip extends StatelessWidget {
  const WorkspaceColorChip({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.pill),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Color(value),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.textPrimary : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(LucideIcons.check300, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

class WorkspaceIconChip extends StatelessWidget {
  const WorkspaceIconChip({
    super.key,
    required this.iconKey,
    required this.selected,
    required this.colorValue,
    required this.onTap,
  });

  final String iconKey;
  final bool selected;
  final int colorValue;
  final VoidCallback onTap;

  static IconData iconFor(String k) => switch (k) {
    'building' => LucideIcons.building2,
    'rocket' => LucideIcons.rocket300,
    'code' => LucideIcons.code300,
    'globe' => LucideIcons.globe300,
    'zap' => LucideIcons.zap300,
    _ => LucideIcons.briefcase300,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Color(colorValue).withValues(alpha: 0.15)
              : c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(
            color: selected ? Color(colorValue) : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconFor(iconKey),
              size: 14,
              color: selected ? Color(colorValue) : c.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              iconKey,
              style: context.typography.caption.copyWith(
                color: selected ? Color(colorValue) : c.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
