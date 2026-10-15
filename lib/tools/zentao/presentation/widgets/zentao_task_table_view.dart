import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/value_objects/ticket_sort.dart';
import '../../../../core/domain/value_objects/zentao_board_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/zentao_table_providers.dart';
import '../providers/zentao_table_sort.dart';
import 'zentao_sortable_header_cell.dart';
import 'zentao_task_column_parts.dart';
import 'zentao_task_row.dart';
import 'zentao_task_sort_menu_button.dart';

/// The ZenTao task list as modern interactive card rows (Linear / GitHub inspired).
class ZenTaoTaskTableView extends ConsumerWidget {
  const ZenTaoTaskTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;
    final table = ref.watch(zentaoTaskTableProvider);
    final pending = table.pending;
    final currentSort = ref.watch(zentaoTaskTableSortProvider);
    final rows = table.rows;

    if (rows.isEmpty && pending == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(s.xl5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.listFilter300, size: 40, color: c.textTertiary),
              SizedBox(height: s.md),
              Text(
                l.emptyTitle,
                style: context.typography.titleSm.copyWith(
                  color: c.textPrimary,
                ),
              ),
              SizedBox(height: s.xs),
              Text(
                l.emptyDesc,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top list sub-header with task count & quick sort control
        Padding(
          padding: EdgeInsets.fromLTRB(s.xl, s.xs, s.xl, s.xs),
          child: Row(
            children: [
              Text(
                l.dashboardTaskCount(rows.length),
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ZenTaoTaskSortMenuButton(
                currentSort: currentSort,
                onSort: (field) => ref
                    .read(zentaoTaskTableSortProvider.notifier)
                    .sortBy(field),
              ),
            ],
          ),
        ),

        // Table Card
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(s.xl, 0, s.xl, s.md),
            child: Container(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(context.radii.card),
                border: Border.all(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _TaskTableHeader(
                    currentSort: currentSort,
                    onSort: (field) => ref
                        .read(zentaoTaskTableSortProvider.notifier)
                        .sortBy(field),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rows.length + (pending != null ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, thickness: 1, color: c.border),
                      itemBuilder: (context, index) {
                        if (index < rows.length) {
                          return ZenTaoTaskRow(ticket: rows[index]);
                        }
                        return ZenTaoTaskColumnFooter(
                          column: pending!,
                          visible: rows
                              .where((t) => zentaoTaskColumnFor(t) == pending)
                              .length,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskTableHeader extends StatelessWidget {
  const _TaskTableHeader({required this.currentSort, required this.onSort});

  final TicketSort currentSort;
  final ValueChanged<TicketSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: s.lg),
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          ZenTaoSortableHeaderCell(
            label: l.tableColumnId,
            field: TicketSortField.id,
            currentSort: currentSort,
            onSort: onSort,
            width: 90,
          ),
          SizedBox(width: s.md),
          ZenTaoSortableHeaderCell(
            label: l.tableColumnTitle,
            field: TicketSortField.title,
            currentSort: currentSort,
            onSort: onSort,
            flex: 1,
          ),
          SizedBox(width: s.md),
          ZenTaoSortableHeaderCell(
            label: l.assignedTo,
            field: TicketSortField.assignee,
            currentSort: currentSort,
            onSort: onSort,
            width: 150,
          ),
          SizedBox(width: s.md),
          ZenTaoSortableHeaderCell(
            label: l.tableColumnSprint,
            currentSort: currentSort,
            width: 90,
          ),
          SizedBox(width: s.md),
          ZenTaoSortableHeaderCell(
            label: l.status,
            field: TicketSortField.status,
            currentSort: currentSort,
            onSort: onSort,
            width: 115,
          ),
          SizedBox(width: s.md),
          ZenTaoSortableHeaderCell(
            label: l.tableColumnDue,
            currentSort: currentSort,
            width: 85,
          ),
        ],
      ),
    );
  }
}

/// Alias for ZenTaoTaskTableView matching the modern list layout.
typedef ZenTaoTaskListView = ZenTaoTaskTableView;
