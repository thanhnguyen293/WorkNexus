import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/hover_surface.dart';

/// A labeled group of filter chips (uppercase heading + wrapped chips). Shared by
/// the popover's facet and generic filter sections.
class FilterGroup extends StatelessWidget {
  const FilterGroup({required this.label, required this.children, super.key});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // A single-option group can't filter anything (picking the only value is a
    // no-op), so hide it along with empty groups.
    if (children.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: label),
          SizedBox(height: context.spacing.xs),
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
    return HoverSurface(
      onTap: onTap,
      selected: active,
      height: context.sizes.controlSm,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.lg),
      color: active ? c.selectionFill : c.surfaceSubtle,
      borderRadius: BorderRadius.circular(context.radii.pill),
      border: context.borders.showOutline ? Border.all(color: c.border) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: context.spacing.sm,
              height: context.spacing.sm,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: context.spacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.meta.copyWith(
                fontWeight: FontWeight.w500,
                color: active ? c.textPrimary : c.textSecondary,
              ),
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
    );
  }
}
