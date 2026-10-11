import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_count_badge.dart';
import 'hover_surface.dart';

/// One segment of [AppSegmentedTabs].
class AppSegmentedTab {
  const AppSegmentedTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.loading = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  /// Shown beside the label when set.
  final int? count;

  /// Shows a spinner in place of the count while the tab's view loads.
  final bool loading;
}

/// View tabs (All / Unclosed, Issues / Merge Requests…) as a segmented
/// control: the active segment is raised on an inset track, at the toolbar's
/// control height, with an optional count (or a spinner while it loads).
class AppSegmentedTabs extends StatelessWidget {
  const AppSegmentedTabs({super.key, required this.tabs});

  final List<AppSegmentedTab> tabs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      height: context.sizes.controlMd,
      padding: EdgeInsets.all(s.xxs),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
        border: context.cardBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final tab in tabs) _Segment(tab)],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.tab);

  final AppSegmentedTab tab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.sm);
    return HoverSurface(
      onTap: tab.onTap,
      selected: tab.active,
      padding: EdgeInsets.symmetric(horizontal: s.lg),
      alignment: Alignment.center,
      color: tab.active ? c.surface : c.surfaceSubtle,
      borderRadius: radius,
      border: tab.active ? context.cardBorder : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // One weight for both states, so switching tabs moves nothing.
          Text(
            tab.label,
            style: context.typography.bodySm.copyWith(
              color: tab.active ? c.textPrimary : c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (tab.loading) ...[
            SizedBox(width: s.sm),
            SizedBox.square(
              dimension: context.sizes.iconXs,
              child: CircularProgressIndicator(color: c.textTertiary),
            ),
          ] else if (tab.count case final count?) ...[
            SizedBox(width: s.sm),
            AppCountBadge(count, active: tab.active),
          ],
        ],
      ),
    );
  }
}
