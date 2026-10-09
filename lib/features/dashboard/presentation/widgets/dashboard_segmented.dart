import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A compact segmented switch: a pill track with the [selected] segment
/// raised on it. Each segment shows a label and an optional count.
class DashboardSegmented<T> extends StatelessWidget {
  const DashboardSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label, int? count})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    return Container(
      padding: EdgeInsets.all(s.xxs),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seg in segments)
            GestureDetector(
              onTap: () => onChanged(seg.value),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: EdgeInsets.symmetric(
                    horizontal: s.lg,
                    vertical: s.xs,
                  ),
                  decoration: BoxDecoration(
                    color: seg.value == selected ? c.surface : null,
                    borderRadius: BorderRadius.circular(context.radii.sm),
                    boxShadow: seg.value == selected
                        ? [
                            BoxShadow(
                              color: c.scrim.withValues(alpha: 0.08),
                              blurRadius: s.xs,
                              offset: Offset(0, s.xxs / 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: seg.label,
                      children: [
                        if (seg.count case final n?)
                          TextSpan(
                            text: '  $n',
                            style: t.bodySm.copyWith(color: c.textTertiary),
                          ),
                      ],
                    ),
                    style: (seg.value == selected ? t.bodySmStrong : t.bodySm)
                        .copyWith(
                          color: seg.value == selected
                              ? c.textPrimary
                              : c.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
