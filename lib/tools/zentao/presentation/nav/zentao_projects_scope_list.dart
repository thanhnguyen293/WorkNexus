import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/pinned_execution.dart';
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
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );

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

        String keyOf(ProviderProject p) =>
            zentaoProjectPinKey(p.accountId, p.id);

        final pinnedProjects = filtered
            .where((p) => pinned.contains(keyOf(p)))
            .toList();
        final unpinnedProjects = filtered
            .where((p) => !pinned.contains(keyOf(p)))
            .toList();

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

        final recentIds = widget.location.recentScopeIds.toSet();
        final recentProjects = unpinnedProjects
            .where((p) => recentIds.contains(p.id))
            .toList();

        // ZenTao's own grouping by program (or one flat list when the
        // programs are not known).
        final tree = ZenTaoProjectTree.of(unpinnedProjects);

        return Column(
          children: [
            ScopeFilterField(
              placeholder: l.filterProjects,
              onChanged: (val) => setState(() => _filter = val),
            ),
            Expanded(
              child: ScopeListBody(
                // No "all projects" row: ZenTao lists tasks per execution.
                groupTitle: l.zentaoProjectsGroup,
                initiallyExpanded: true,
                cap: 100,
                quickScopeRows: [
                  ScopeQuickRow(
                    label: l.assignedToMe,
                    icon: LucideIcons.user300,
                    selected:
                        widget.location.quickScope == QuickScope.assignedToMe,
                    onTap: () {
                      ref
                          .read(appNavProvider.notifier)
                          .setQuickScope(QuickScope.assignedToMe);
                    },
                  ),
                ],
                pinnedRows: [
                  for (final p in pinnedProjects)
                    ZentaoProjectTreeNode(
                      key: ValueKey('pinned_proj_${p.id}'),
                      account: widget.account,
                      project: p,
                      tickets: tickets,
                      location: widget.location,
                      openCount: openCount(p.id),
                      isPinned: true,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                    ),
                  for (final e in filteredExecutions.where(
                    (e) => !pinnedProjects.any((p) => p.id == e.projectId),
                  ))
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
                recentRows: [
                  for (final p in recentProjects)
                    ScopeRow(
                      name: p.name,
                      count: openCount(p.id),
                      selected: widget.location.scopeId == p.id,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                      onTap: () {
                        ref.read(appNavProvider.notifier).selectScope(p.id);
                        ref
                            .read(selectedZenTaoExecutionProvider.notifier)
                            .clear();
                      },
                    ),
                ],
                allRows: [
                  for (final group in tree.groups)
                    ZentaoProjectSetNode(
                      key: ValueKey('zentao_group_${group.id}'),
                      account: widget.account,
                      group: group,
                      tickets: tickets,
                      location: widget.location,
                      openCountOf: openCount,
                    ),
                  // In no program: after the folders.
                  for (final p in tree.ungrouped)
                    ZentaoProjectTreeNode(
                      key: ValueKey('zentao_proj_${p.id}'),
                      account: widget.account,
                      project: p,
                      tickets: tickets,
                      location: widget.location,
                      openCount: openCount(p.id),
                      isPinned: false,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
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
