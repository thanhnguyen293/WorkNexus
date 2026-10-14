import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../../../../core/widgets/resize_handle.dart';
import 'ticket_table_column.dart';

/// A ticket table's header row: the column labels — sortable ones sort on a
/// click — and a handle on each line between two columns that drags it.
class TicketTableHeader extends StatelessWidget {
  const TicketTableHeader(
    this.columns, {
    super.key,
    required this.sort,
    this.onSort,
    required this.onResize,
    required this.onResizeEnd,
    required this.onResetWidth,
  });

  final List<TicketTableColumn> columns;
  final TicketSort sort;
  final ValueChanged<TicketSortField>? onSort;

  /// The line after `columns[line]` dragged by `dx`; the table picks which
  /// column that resizes.
  final void Function(int line, double dx) onResize;
  final VoidCallback onResizeEnd;

  /// The line after `columns[line]` double-clicked.
  final ValueChanged<int> onResetWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        // A light accent wash: a neutral grey sits too close to the page's
        // own grey (light theme) or the rows (dark) to read as a header.
        color: c.mix(c.card, c.accent, 0.07),
        border: Border(bottom: context.hairlineSide),
      ),
      child: TicketTableCells(
        columns,
        [
          for (final column in columns)
            _HeaderLabel(column: column, sort: sort, onSort: onSort),
        ],
        edges: [
          for (var i = 0; i < columns.length; i++)
            // The last column's right edge is the table's own.
            if (i == columns.length - 1)
              null
            else
              ResizeHandle(
                onDelta: (dx) => onResize(i, dx),
                onEnd: onResizeEnd,
                onReset: () => onResetWidth(i),
              ),
        ],
      ),
    );
  }
}

/// A column's header: its label, and — on a sortable column — the click that
/// sorts by it, with an arrow on the column the table is sorted by.
class _HeaderLabel extends StatelessWidget {
  const _HeaderLabel({required this.column, required this.sort, this.onSort});

  final TicketTableColumn column;
  final TicketSort sort;
  final ValueChanged<TicketSortField>? onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final field = column.sortField;
    final active = field != null && sort.field == field;
    final color = active ? c.textPrimary : c.textTertiary;
    final label = Text(
      column.label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.labelWide.copyWith(color: color),
    );
    final onSort = this.onSort;
    if (field == null || onSort == null) return label;
    return HoverSurface(
      onTap: () => onSort(field),
      tintOnHover: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          SizedBox(width: context.spacing.xs),
          Icon(
            !active
                ? LucideIcons.chevronsUpDown300
                : sort.descending
                ? LucideIcons.arrowDown300
                : LucideIcons.arrowUp300,
            size: context.sizes.iconXs,
            color: color,
          ),
        ],
      ),
    );
  }
}
