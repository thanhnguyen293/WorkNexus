import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/hover_surface.dart';

/// The detail panels' tab strip: text tabs with an accent underline on the
/// active one, over a hairline. Shared by the standard panel (Original /
/// Translation) and the two-pane MR / PR detail (Overview / Commits / Changes)
/// so both read as one control. A tab with an entry in [counts] shows it in a
/// count pill beside its label, as GitLab does (Overview 3 · Changes 13).
class DetailUnderlineTabs<T> extends StatelessWidget {
  const DetailUnderlineTabs({
    super.key,
    required this.labels,
    required this.current,
    required this.onSelect,
    this.counts = const {},
  });

  final Map<T, String> labels;
  final T current;
  final ValueChanged<T> onSelect;
  final Map<T, int> counts;

  @override
  Widget build(BuildContext context) {
    // Full width, so the hairline spans the panel and the tabs sit at the left
    // edge even when the parent column centers its children.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(border: Border(bottom: context.hairlineSide)),
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in labels.entries)
              _UnderlineTab(
                label: e.value,
                count: counts[e.key],
                selected: e.key == current,
                onTap: () => onSelect(e.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineTab extends StatelessWidget {
  const _UnderlineTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return HoverSurface(
      onTap: onTap,
      selected: selected,
      height: context.sizes.controlLg,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.xl),
      border: Border(
        bottom: BorderSide(
          color: selected ? c.accent : Colors.transparent,
          width: context.borders.thick,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: context.typography.secondary.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? c.textPrimary : c.textSecondary,
            ),
          ),
          if (count case final count?) ...[
            SizedBox(width: context.spacing.sm),
            AppCountBadge(count),
          ],
        ],
      ),
    );
  }
}
