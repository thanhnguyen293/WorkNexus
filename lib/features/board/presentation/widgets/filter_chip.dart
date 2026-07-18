import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A labeled group of filter chips (uppercase heading + wrapped chips). Shared by
/// the popover's facet and generic filter sections.
class FilterGroup extends StatelessWidget {
  const FilterGroup({required this.label, required this.children, super.key});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: context.typography.label.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.sm,
            children: children,
          ),
        ],
      ),
    );
  }
}

/// A selectable filter chip: optional leading dot, label, optional trailing count.
class FilterOptionChip extends StatelessWidget {
  const FilterOptionChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.dotColor,
    this.count,
    super.key,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? dotColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.pill),
          border: context.borders.showOutline
              ? Border.all(color: c.border)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.spacing.xs),
            ],
            Text(
              label,
              style: context.typography.meta.copyWith(
                fontWeight: FontWeight.w500,
                color: active ? c.textPrimary : c.textSecondary,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: context.spacing.xs),
              Text(
                '$count',
                style: context.typography.meta.copyWith(color: c.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A prominent icon+label quick-filter toggle (e.g. "Assigned to me"). Accent
/// fill + border when [active].
class FilterQuickToggle extends StatelessWidget {
  const FilterQuickToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.accent : c.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
        decoration: BoxDecoration(
          color: active ? c.selectionFill : c.surfaceSubtle,
          borderRadius: BorderRadius.circular(context.radii.md),
          border: Border.all(color: active ? c.mixT(c.accent, 0.5) : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            SizedBox(width: context.spacing.xs),
            Text(
              label,
              style: context.typography.meta.copyWith(
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
