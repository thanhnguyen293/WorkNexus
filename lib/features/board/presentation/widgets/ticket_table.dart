import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../board_providers.dart';

/// One column of a [TicketTable].
class TicketTableColumn {
  const TicketTableColumn({
    required this.label,
    required this.cell,
    this.width,
    this.alignEnd = false,
    this.sortField,
  });

  final String label;

  /// The cell for one ticket.
  final Widget Function(Ticket ticket) cell;

  /// A fixed width; null takes the width left over (the title).
  final double? width;

  /// Right-aligns the header and cells (numbers, dates).
  final bool alignEnd;

  /// What clicking the header sorts by; null leaves the column unsortable.
  final TicketSortField? sortField;
}

/// The narrowest the leftover (title) column gets before the table scrolls
/// sideways instead.
const _kMinFlexWidth = 320.0;

/// A dense, ZenTao-style ticket table: a header over one row per ticket,
/// clicking a row opens the ticket. [footer] closes the list — the paging
/// footer that loads more rows as it scrolls into reach.
class TicketTable extends StatelessWidget {
  const TicketTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
    this.sort = TicketSort.newest,
    this.onSort,
  });

  final List<TicketTableColumn> columns;
  final List<Ticket> rows;
  final Widget? footer;

  /// The order the rows are in, marked on its column's header.
  final TicketSort sort;

  /// Sorts by a column whose header was clicked; null makes no column
  /// sortable.
  final ValueChanged<TicketSortField>? onSort;

  @override
  Widget build(BuildContext context) {
    final fixed = columns.fold<double>(0, (sum, c) => sum + (c.width ?? 0));
    final gutter = context.spacing.xl * 2;
    final radius = BorderRadius.circular(context.radii.lg);
    // One card on the board's background, like a kanban column: the header
    // and rows sit on the card, not straight on the page.
    return Padding(
      padding: EdgeInsets.all(context.spacing.xl2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // Rows on the card colour, like the board's ticket cards.
          color: context.colors.card,
          borderRadius: radius,
          border: context.cardBorder,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth,
                fixed + _kMinFlexWidth + gutter,
              );
              return Scrollbar(
                child: SingleChildScrollView(
                  key: const PageStorageKey('ticket-table-x'),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        _HeaderRow(columns, sort: sort, onSort: onSort),
                        Expanded(
                          child: ListView.builder(
                            key: const PageStorageKey('ticket-table-y'),
                            itemCount: rows.length + (footer == null ? 0 : 1),
                            itemBuilder: (context, i) => i == rows.length
                                ? Padding(
                                    padding: EdgeInsets.all(context.spacing.lg),
                                    child: footer,
                                  )
                                : _TableRow(
                                    columns,
                                    rows[i],
                                    // The card's edge closes the last row.
                                    last:
                                        footer == null && i == rows.length - 1,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Lays [cells] out in [columns]' widths, padded like every table row.
class _Cells extends StatelessWidget {
  const _Cells(this.columns, this.cells);

  final List<TicketTableColumn> columns;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _Cell(column: columns[i], child: cells[i]),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.column, required this.child});

  final TicketTableColumn column;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aligned = Padding(
      padding: EdgeInsets.only(right: context.spacing.lg),
      child: Align(
        alignment: column.alignEnd
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: child,
      ),
    );
    final width = column.width;
    return width == null
        ? Expanded(child: aligned)
        : SizedBox(width: width, child: aligned);
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow(this.columns, {required this.sort, this.onSort});

  final List<TicketTableColumn> columns;
  final TicketSort sort;
  final ValueChanged<TicketSortField>? onSort;

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
      child: _Cells(columns, [
        for (final column in columns)
          _HeaderLabel(column: column, sort: sort, onSort: onSort),
      ]),
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

class _TableRow extends ConsumerWidget {
  const _TableRow(this.columns, this.ticket, {this.last = false});

  final List<TicketTableColumn> columns;
  final Ticket ticket;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(openTicketIdProvider) == ticket.id;
    final pending = ref.watch(
      ticketActionPendingProvider.select((ids) => ids.contains(ticket.id)),
    );
    return Opacity(
      opacity: pending ? 0.48 : 1,
      child: HoverSurface(
        onTap: pending
            ? null
            : () => ref.read(appNavProvider.notifier).openTicket(ticket.id),
        color: selected ? c.selectionFill : Colors.transparent,
        border: last ? null : Border(bottom: context.hairlineSide),
        child: _Cells(columns, [
          for (final column in columns) column.cell(ticket),
        ]),
      ),
    );
  }
}
