import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/scope_filter_field.dart';
import '../../../../shared/shell_pane/scope_list_body.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/entities/zentao_project_group.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_scope_providers.dart';
import '../util/open_execution_board.dart';
import 'zentao_project_set_node.dart';
import 'zentao_project_tree_node.dart';

/// Scope list for ZenTao Tasks: quick scopes + pinned / recent / hierarchical project sets tree.
class ZentaoProjectsScopeList extends ConsumerStatefulWidget {
  const ZentaoProjectsScopeList({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<ZentaoProjectsScopeList> createState() =>
      _ZentaoProjectsScopeListState();
}

class _ZentaoProjectsScopeListState
    extends ConsumerState<ZentaoProjectsScopeList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final projectsAsync = ref.watch(zentaoProjectsProvider(widget.account.id));
    final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];

    return projectsAsync.when(
      data: (projects) {
        final query = _filter.trim().toLowerCase();
        final filtered = query.isEmpty
            ? projects
            : projects.where((p) {
                if (p.name.toLowerCase().contains(query)) return true;
                final prog = p.programName?.toLowerCase();
                if (prog != null && prog.contains(query)) return true;
                return false;
              }).toList();

        int openCount(String projectId) => tickets
            .where(
              (t) =>
                  t.accountId == widget.account.id &&
                  t.status != UnifiedStatus.done &&
                  zentaoTaskInProject(t, projectId),
            )
            .length;

        final pinnedExecutions = ref
            .watch(appSettingsProvider.select((s) => s.pinnedExecutions))
            .where((e) => e.accountId == widget.account.id)
            .toList();
        final filteredExecutions = query.isEmpty
            ? pinnedExecutions
            : pinnedExecutions
                  .where((e) => e.name.toLowerCase().contains(query))
                  .toList();

        int executionOpenCount(String executionId) => tickets
            .where(
              (t) =>
                  t.accountId == widget.account.id &&
                  t.status != UnifiedStatus.done &&
                  switch (t.providerEntity) {
                    ZenTaoTaskEntity(:final execution) =>
                      execution == executionId,
                    _ => false,
                  },
            )
            .length;

        final selectedExec = ref.watch(selectedZenTaoExecutionProvider);

        // ZenTao's own grouping by program (or one flat list when the
        // programs are not known). Projects only hold executions: no pins,
        // no selection. No "recent" rows either — the nav keeps only scope
        // ids, and an execution's name and project are not known without
        // loading its project's executions.
        final tree = ZenTaoProjectTree.of(filtered);

        return Column(
          children: [
            ScopeFilterField(
              placeholder: l.filterProjects,
              onChanged: (val) => setState(() => _filter = val),
            ),
            Expanded(
              child: ScopeListBody(
                // No quick rows: ZenTao lists tasks per execution only, and
                // the board's own "Assigned to me" chip narrows to your tasks.
                groupTitle: l.zentaoProjectsGroup,
                initiallyExpanded: true,
                cap: 100,
                // Only executions are pinned (lifted out of the tree).
                pinnedRows: [
                  for (final e in filteredExecutions)
                    ScopeRow(
                      name: e.name,
                      color: context.colors.info,
                      count: executionOpenCount(e.executionId),
                      selected:
                          selectedExec?.accountId == e.accountId &&
                          selectedExec?.executionId == e.executionId,
                      isPinned: true,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedExecution(e),
                      onTap: () => openExecutionBoard(
                        context,
                        ref,
                        ProviderExecution(
                          id: e.executionId,
                          name: e.name,
                          projectId: e.projectId,
                          accountId: e.accountId,
                        ),
                      ),
                    ),
                ],
                allRows: [
                  for (final group in tree.groups)
                    ZentaoProjectSetNode(
                      key: ValueKey('zentao_group_${group.id}'),
                      account: widget.account,
                      group: group,
                      openCountOf: openCount,
                    ),
                  // In no program: after the folders.
                  for (final p in tree.ungrouped)
                    ZentaoProjectTreeNode(
                      key: ValueKey('zentao_proj_${p.id}'),
                      account: widget.account,
                      project: p,
                      openCount: openCount(p.id),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SidebarStatusRow(label: l.loadingProjects, loading: true),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SidebarStatusRow(
          label: l.projectsUnavailable,
          isError: true,
          onRetry: () =>
              ref.invalidate(zentaoProjectsProvider(widget.account.id)),
        ),
      ),
    );
  }
}
