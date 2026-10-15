import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Bottom summary status line for the ZenTao task & bug manager.
class ZenTaoTaskManagerFooter extends StatelessWidget {
  const ZenTaoTaskManagerFooter({
    super.key,
    required this.totalCount,
    this.waitingCount = 0,
    this.doingCount = 0,
    this.doneCount = 0,
    this.selectedCount = 0,
  });

  final int totalCount;
  final int waitingCount;
  final int doingCount;
  final int doneCount;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(top: context.hairlineSide),
      ),
      child: Row(
        children: [
          if (selectedCount > 0) ...[
            Text(
              'Selected: $selectedCount',
              style: context.typography.monoXs.copyWith(
                color: c.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: context.spacing.md),
            Container(width: 1, height: 12, color: c.border),
            SizedBox(width: context.spacing.md),
          ],

          Text(
            'Total: $totalCount tasks',
            style: context.typography.monoXs.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: context.spacing.md),

          _MetricItem(
            label: 'Waiting',
            count: waitingCount,
            color: c.textTertiary,
          ),
          SizedBox(width: context.spacing.md),

          _MetricItem(label: 'Doing', count: doingCount, color: c.accent),
          SizedBox(width: context.spacing.md),

          _MetricItem(label: 'Done', count: doneCount, color: c.success),

          const Spacer(),

          Text(
            'ZenTao High-Density Mode',
            style: context.typography.monoXs.copyWith(
              color: c.textTertiary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: context.typography.monoXs.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
