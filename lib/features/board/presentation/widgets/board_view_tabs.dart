import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';

/// The height every control on the board toolbar shares, so the tabs, search,
/// filters and refresh line up.
const kBoardToolbarControlHeight = 32.0;

/// One segment of [BoardViewTabs].
class BoardViewTab {
  const BoardViewTab({
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

/// A board's view tabs (All / Unclosed, Issues / Merge Requests…) as a
/// segmented control on the toolbar: the active segment is raised on the
/// toolbar's inset track, at the toolbar's control height.
class BoardViewTabs extends StatelessWidget {
  const BoardViewTabs({super.key, required this.tabs});

  final List<BoardViewTab> tabs;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Container(
      height: kBoardToolbarControlHeight,
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

  final BoardViewTab tab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final radius = BorderRadius.circular(context.radii.sm);
    return HoverSurface(
      onTap: tab.onTap,
      duration: const Duration(milliseconds: 150),
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
              dimension: s.lg,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: c.textTertiary,
              ),
            ),
          ] else if (tab.count case final count?) ...[
            SizedBox(width: s.sm),
            _CountPill(count, active: tab.active),
          ],
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.count, {required this.active});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: active ? c.mixT(c.accent, 0.14) : c.surface,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        '$count',
        style: context.typography.monoXs.copyWith(
          color: active ? c.accent : c.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
