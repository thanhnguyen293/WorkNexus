import 'package:flutter/material.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Sticky header for the high-density ZenTao task table view.
class ZenTaoTaskTableHeader extends StatelessWidget {
  const ZenTaoTaskTableHeader({
    super.key,
    this.allSelected = false,
    this.onToggleSelectAll,
  });

  final bool allSelected;
  final VoidCallback? onToggleSelectAll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: allSelected,
              onChanged: onToggleSelectAll != null
                  ? (_) => onToggleSelectAll!()
                  : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          SizedBox(width: context.spacing.xs),

          // ID
          const SizedBox(
            width: 68,
            child: _HeaderCell(label: 'ID', sortable: true),
          ),
          SizedBox(width: context.spacing.xs),

          // Name (Title + Module + Delay)
          const Expanded(
            flex: 5,
            child: _HeaderCell(label: 'Name', sortable: true),
          ),
          SizedBox(width: context.spacing.xs),

          // Priority
          const SizedBox(
            width: 36,
            child: Center(child: _HeaderCell(label: 'P', sortable: true)),
          ),
          SizedBox(width: context.spacing.xs),

          // Status
          const SizedBox(width: 84, child: _HeaderCell(label: 'Status')),
          SizedBox(width: context.spacing.xs),

          // AssignTo
          const SizedBox(width: 110, child: _HeaderCell(label: 'AssignTo')),
          SizedBox(width: context.spacing.xs),

          // FinishedBy
          const SizedBox(width: 100, child: _HeaderCell(label: 'FinishedBy')),
          SizedBox(width: context.spacing.xs),

          // Deadline
          const SizedBox(
            width: 105,
            child: _HeaderCell(label: 'Deadline', sortable: true),
          ),
          SizedBox(width: context.spacing.xs),

          // Action
          const SizedBox(width: 100, child: _HeaderCell(label: 'Action')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, this.sortable = false});

  final String label;
  final bool sortable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.monoXs.copyWith(
              color: c.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (sortable) ...[
          const SizedBox(width: 2),
          Icon(Icons.unfold_more_rounded, size: 13, color: c.textTertiary),
        ],
      ],
    );
  }
}
