import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_spacing.dart';

/// One column of a `TicketTable`.
class TicketTableColumn {
  const TicketTableColumn({
    required this.id,
    required this.label,
    required this.cell,
    this.width,
    this.alignEnd = false,
    this.sortField,
  });

  /// Names the column within its table, so a width it is dragged to is kept.
  final String id;

  final String label;

  /// The cell for one ticket.
  final Widget Function(Ticket ticket) cell;

  /// A fixed width — resizable from the header; null takes the width left
  /// over (the title).
  final double? width;

  /// Right-aligns the header and cells (numbers, dates).
  final bool alignEnd;

  /// What clicking the header sorts by; null leaves the column unsortable.
  final TicketSortField? sortField;

  TicketTableColumn withWidth(double width) => TicketTableColumn(
    id: id,
    label: label,
    cell: cell,
    width: width,
    alignEnd: alignEnd,
    sortField: sortField,
  );
}

/// A row's inset from the table's sides; with a cell's own padding, the
/// first and last cells' content sits `xl` in from the card's edges.
double ticketTableInset(BuildContext context) => context.spacing.xs;

/// Lays [cells] out in [columns]' widths, padded like every table row, with
/// a hairline between columns. [edges] — when given — lie over each cell's
/// right edge (the header's resize handles).
class TicketTableCells extends StatelessWidget {
  const TicketTableCells(this.columns, this.cells, {super.key, this.edges});

  final List<TicketTableColumn> columns;
  final List<Widget> cells;
  final List<Widget?>? edges;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    // Painted over the full row height, not per cell, so the lines meet the
    // next row's and run unbroken down the table. Behind the cells, so a
    // resize handle's accent line covers its divider.
    return CustomPaint(
      painter: _ColumnDividers(
        widths: [for (final c in columns) c.width],
        inset: ticketTableInset(context),
        side: context.hairlineSide,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ticketTableInset(context),
          vertical: s.md,
        ),
        child: Row(
          children: [
            for (var i = 0; i < columns.length; i++)
              _Cell(column: columns[i], edge: edges?[i], child: cells[i]),
          ],
        ),
      ),
    );
  }
}

/// A vertical line on the right edge of every column but the last; null
/// [widths] share what the fixed ones leave, as the row's `Expanded`s do.
class _ColumnDividers extends CustomPainter {
  const _ColumnDividers({
    required this.widths,
    required this.inset,
    required this.side,
  });

  final List<double?> widths;
  final double inset;
  final BorderSide side;

  @override
  void paint(Canvas canvas, Size size) {
    final fixed = widths.fold<double>(0, (sum, w) => sum + (w ?? 0));
    final flexCount = widths.where((w) => w == null).length;
    final flex = flexCount == 0
        ? 0.0
        : ((size.width - inset * 2 - fixed) / flexCount).clamp(0.0, size.width);
    final paint = side.toPaint();
    var x = inset;
    for (final w in widths.take(widths.length - 1)) {
      x += w ?? flex;
      // Centered on the column's last pixel, inside its width.
      final line = x - side.width / 2;
      canvas.drawLine(Offset(line, 0), Offset(line, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_ColumnDividers old) =>
      old.inset != inset || old.side != side || !listEquals(old.widths, widths);
}

class _Cell extends StatelessWidget {
  const _Cell({required this.column, required this.child, this.edge});

  final TicketTableColumn column;
  final Widget child;
  final Widget? edge;

  @override
  Widget build(BuildContext context) {
    final aligned = Padding(
      // Both sides, so a divider sits between two equal gaps.
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
      child: Align(
        alignment: column.alignEnd
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: child,
      ),
    );
    final edge = this.edge;
    final content = edge == null
        ? aligned
        : Stack(
            children: [
              aligned,
              Positioned(top: 0, bottom: 0, right: 0, child: edge),
            ],
          );
    final width = column.width;
    return width == null
        ? Expanded(child: content)
        : SizedBox(width: width, child: content);
  }
}
