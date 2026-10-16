import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/scope_filter_field.dart';
import '../../../../shared/shell_pane/scope_list_body.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/entities/gitlab_project_tree.dart';
import '../providers/gitlab_board_providers.dart';
import '../providers/gitlab_scope.dart';
import 'gitlab_group_node_widget.dart';
import 'gitlab_project_tree_node.dart';

/// Scope list for GitLab: quick scopes (All projects, Assigned to me) +
/// pinned / recent / hierarchical namespace tree.
class GitlabProjectsScopeList extends ConsumerStatefulWidget {
  const GitlabProjectsScopeList({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<GitlabProjectsScopeList> createState() =>
      _GitlabProjectsScopeListState();
}

class _GitlabProjectsScopeListState
    extends ConsumerState<GitlabProjectsScopeList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final projectsAsync = ref.watch(gitlabProjectsProvider(widget.account.id));
    final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );

    return projectsAsync.when(
      data: (projects) {
        final query = _filter.trim().toLowerCase();
        final filtered = query.isEmpty
            ? projects
            : projects
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

        int openCount(String projectId) => tickets
            .where(
              (t) =>
                  t.accountId == widget.account.id &&
                  t.status != UnifiedStatus.done &&
                  gitlabTicketInProject(t, projectId),
            )
            .length;

        String keyOf(ProviderProject p) => '${p.accountId}:${p.id}';

        final pinnedProjects = filtered
            .where((p) => pinned.contains(keyOf(p)))
            .toList();
        final unpinnedProjects = filtered
            .where((p) => !pinned.contains(keyOf(p)))
            .toList();

        final recentIds = widget.location.recentScopeIds.toSet();
        final recentProjects = unpinnedProjects
            .where((p) => recentIds.contains(p.id))
            .toList();

        final placeholder = projects.isNotEmpty
            ? l.filterProjectsCount(projects.length)
            : l.filterProjects;

        final tree = GitLabProjectTree.build(unpinnedProjects);

        return Column(
          children: [
            ScopeFilterField(
              placeholder: placeholder,
              onChanged: (val) => setState(() => _filter = val),
            ),
            Expanded(
              child: ScopeListBody(
                groupTitle: l.allProjects,
                initiallyExpanded: true,
                cap: 100,
                quickScopeRows: [
                  ScopeQuickRow(
                    label: l.allProjects,
                    icon: LucideIcons.layers300,
                    selected:
                        widget.location.scopeId == null &&
                        widget.location.quickScope == QuickScope.all,
                    onTap: () {
                      ref.read(appNavProvider.notifier).selectScope(null);
                      ref
                          .read(appNavProvider.notifier)
                          .setQuickScope(QuickScope.all);
                      ref.read(selectedGitLabProjectProvider.notifier).clear();
                    },
                  ),
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
                    ScopeRow(
                      name: p.name,
                      count: openCount(p.id),
                      selected: widget.location.scopeId == p.id,
                      isPinned: true,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                      onTap: () {
                        ref.read(appNavProvider.notifier).selectScope(p.id);
                        ref
                            .read(selectedGitLabProjectProvider.notifier)
                            .select(p);
                        ref
                            .read(filterStateProvider.notifier)
                            .openBoard(ref.read(boardKeyProvider));
                      },
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
                            .read(selectedGitLabProjectProvider.notifier)
                            .select(p);
                        ref
                            .read(filterStateProvider.notifier)
                            .openBoard(ref.read(boardKeyProvider));
                      },
                    ),
                ],
                allRows: [
                  for (final group in tree.rootGroups)
                    GitLabGroupNodeWidget(
                      key: ValueKey('gitlab_group_${group.fullPath}'),
                      account: widget.account,
                      node: group,
                      location: widget.location,
                      openCountOf: openCount,
                      isRoot: true,
                    ),
                  for (final p in tree.rootProjects)
                    GitLabProjectTreeNode(
                      key: ValueKey('gitlab_proj_${p.id}'),
                      project: p,
                      openCount: openCount(p.id),
                      selected: widget.location.scopeId == p.id,
                      isPinned: pinned.contains(keyOf(p)),
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
              ref.invalidate(gitlabProjectsProvider(widget.account.id)),
        ),
      ),
    );
  }
}
