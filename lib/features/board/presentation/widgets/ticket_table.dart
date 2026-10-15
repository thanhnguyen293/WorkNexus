import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hover_surface.dart';
import '../board_providers.dart';
import 'ticket_table_column.dart';
import 'ticket_table_header.dart';

/// The narrowest the leftover (title) column gets before the table scrolls
/// sideways instead.
const _kMinFlexWidth = 320.0;

/// The range a fixed-width column can be dragged within.
const _kMinColumnWidth = 48.0;
const _kMaxColumnWidth = 640.0;

/// A dense, ZenTao-style ticket table: a header over one row per ticket,
/// clicking a row opens the ticket. [footer] closes the list — the paging
/// footer that loads more rows as it scrolls into reach. The lines between
/// columns drag in the header to resize them (a double-click restores the
/// default); the widths are kept per [id] across restarts.
class TicketTable extends ConsumerStatefulWidget {
  const TicketTable({
    super.key,
    required this.id,
    required this.columns,
    required this.rows,
    this.footer,
    this.sort = TicketSort.newest,
    this.onSort,
  });

  /// Names the table, so its columns' widths are kept apart from another's.
  final String id;

  final List<TicketTableColumn> columns;
  final List<Ticket> rows;
  final Widget? footer;

  /// The order the rows are in, marked on its column's header.
  final TicketSort sort;

  /// Sorts by a column whose header was clicked; null makes no column
  /// sortable.
  final ValueChanged<TicketSortField>? onSort;

  @override
  ConsumerState<TicketTable> createState() => _TicketTableState();
}

class _TicketTableState extends ConsumerState<TicketTable> {
  /// Widths of the columns mid-drag, by column id; written to settings once
  /// the drag lets go, so a drag is smooth and saved once.
  final _dragWidths = <String, double>{};

  String _key(TicketTableColumn column) => '${widget.id}.${column.id}';

  /// The column a drag on the line after `columns[line]` resizes, and which
  /// way, so the line follows the pointer. Lines left of the title are placed
  /// from the table's left edge and move with the column before them. Lines
  /// right of it are placed from the right edge — the title takes up the
  /// slack — so they move with the column after them; unless the title is
  /// already at its narrowest and the table scrolls, when every line is
  /// placed from the left again.
  (TicketTableColumn, double) _target(
    List<TicketTableColumn> columns,
    int line, {
    required bool overflowing,
  }) {
    final title = columns.indexWhere((c) => c.width == null);
    return title < 0 || line < title || (overflowing && line > title)
        ? (columns[line], 1)
        : (columns[line + 1], -1);
  }

  void _resize(
    List<TicketTableColumn> columns,
    int line,
    double dx, {
    required bool overflowing,
  }) {
    final (column, sign) = _target(columns, line, overflowing: overflowing);
    setState(() {
      // [column] carries its current width, the drag's included.
      _dragWidths[column.id] = ((column.width ?? 0) + dx * sign)
          .clamp(_kMinColumnWidth, _kMaxColumnWidth)
          .toDouble();
    });
  }

  void _saveWidths() {
    final settings = ref.read(appSettingsProvider.notifier);
    for (final column in widget.columns) {
      final width = _dragWidths[column.id];
      if (width != null) settings.setTableColumnWidth(_key(column), width);
    }
    setState(_dragWidths.clear);
  }

  void _resetWidth(
    List<TicketTableColumn> columns,
    int line, {
    required bool overflowing,
  }) {
    final (column, _) = _target(columns, line, overflowing: overflowing);
    ref
        .read(appSettingsProvider.notifier)
        .setTableColumnWidth(_key(column), null);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(
      appSettingsProvider.select((s) => s.tableColumnWidths),
    );
    final columns = [
      for (final column in widget.columns)
        switch (column.width) {
          null => column,
          final width => column.withWidth(
            _dragWidths[column.id] ?? saved[_key(column)] ?? width,
          ),
        },
    ];
    final rows = widget.rows;
    final footer = widget.footer;
    final fixed = columns.fold<double>(0, (sum, c) => sum + (c.width ?? 0));
    final gutter = ticketTableInset(context) * 2;
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
              final overflowing = width > constraints.maxWidth;
              return Scrollbar(
                child: SingleChildScrollView(
                  key: const PageStorageKey('ticket-table-x'),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      children: [
                        TicketTableHeader(
                          columns,
                          sort: widget.sort,
                          onSort: widget.onSort,
                          onResize: (line, dx) => _resize(
                            columns,
                            line,
                            dx,
                            overflowing: overflowing,
                          ),
                          onResizeEnd: _saveWidths,
                          onResetWidth: (line) => _resetWidth(
                            columns,
                            line,
                            overflowing: overflowing,
                          ),
                        ),
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
                                    key: ValueKey(rows[i].id),
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

class _TableRow extends ConsumerWidget {
  const _TableRow(this.columns, this.ticket, {this.last = false, super.key});

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
        child: TicketTableCells(columns, [
          for (final column in columns) column.cell(ticket),
        ]),
      ),
    );
  }
}
