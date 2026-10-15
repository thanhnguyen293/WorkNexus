import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zentao_filter_providers.dart';
import 'zentao_module_filter_sidebar.dart';
import 'zentao_task_manager_footer.dart';
import 'zentao_task_table_header.dart';
import 'zentao_task_table_row.dart';

/// Full high-density Table View for ZenTao Tasks with sticky header,
/// module sidebar, and metrics footer.
class ZenTaoTaskManagerTableView extends ConsumerStatefulWidget {
  const ZenTaoTaskManagerTableView({super.key, required this.tickets});

  final List<Ticket> tickets;

  @override
  ConsumerState<ZenTaoTaskManagerTableView> createState() =>
      _ZenTaoTaskManagerTableViewState();
}

class _ZenTaoTaskManagerTableViewState
    extends ConsumerState<ZenTaoTaskManagerTableView> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedModule = ref.watch(selectedModuleProvider);

    // Apply module filter if active
    final filteredTickets = selectedModule == null
        ? widget.tickets
        : widget.tickets.where((t) {
            final hasLabel = t.labels.contains('module:$selectedModule');
            final hasBracket = t.title.contains('[$selectedModule]');
            return hasLabel || hasBracket;
          }).toList();

    final allSelected =
        filteredTickets.isNotEmpty &&
        _selectedIds.length == filteredTickets.length;

    int waitingCount = 0;
    int doingCount = 0;
    int doneCount = 0;

    for (final t in filteredTickets) {
      if (t.status == UnifiedStatus.inprogress) {
        doingCount++;
      } else if (t.status == UnifiedStatus.done ||
          t.status == UnifiedStatus.review) {
        doneCount++;
      } else {
        waitingCount++;
      }
    }

    return ColoredBox(
      color: c.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left module sidebar
          ZenTaoModuleFilterSidebar(totalCount: widget.tickets.length),

          // Main table content
          Expanded(
            child: Column(
              children: [
                // Sticky Header
                ZenTaoTaskTableHeader(
                  allSelected: allSelected,
                  onToggleSelectAll: () {
                    setState(() {
                      if (allSelected) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(filteredTickets.map((t) => t.id));
                      }
                    });
                  },
                ),

                // Virtualized Table Body
                Expanded(
                  child: filteredTickets.isEmpty
                      ? Center(
                          child: Text(
                            'No tasks found for this filter',
                            style: context.typography.bodySm.copyWith(
                              color: c.textTertiary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredTickets.length,
                          itemExtent: 42,
                          itemBuilder: (context, i) {
                            final ticket = filteredTickets[i];
                            return ZenTaoTaskTableRow(
                              ticket: ticket,
                              selected: _selectedIds.contains(ticket.id),
                              onToggleSelect: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(ticket.id);
                                  } else {
                                    _selectedIds.remove(ticket.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),

                // Footer
                ZenTaoTaskManagerFooter(
                  totalCount: filteredTickets.length,
                  waitingCount: waitingCount,
                  doingCount: doingCount,
                  doneCount: doneCount,
                  selectedCount: _selectedIds.length,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
