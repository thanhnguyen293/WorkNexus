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
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/shell_pane/scope_filter_field.dart';
import '../../../../shared/shell_pane/scope_list_body.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../providers/github_board_providers.dart';

/// Scope list for GitHub: quick scopes (All repositories, Review requested) +
/// pinned / recent / all repositories.
class GithubReposScopeList extends ConsumerStatefulWidget {
  const GithubReposScopeList({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<GithubReposScopeList> createState() =>
      _GithubReposScopeListState();
}

class _GithubReposScopeListState extends ConsumerState<GithubReposScopeList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final reposAsync = ref.watch(githubReposProvider(widget.account.id));
    final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );

    return reposAsync.when(
      data: (repos) {
        final query = _filter.trim().toLowerCase();
        final filtered = query.isEmpty
            ? repos
            : repos.where((r) => r.name.toLowerCase().contains(query)).toList();

        int openCount(String repoId) => tickets
            .where(
              (t) =>
                  t.accountId == widget.account.id &&
                  t.status != UnifiedStatus.done &&
                  ((t.providerEntity is GitHubItemEntity &&
                          (t.providerEntity as GitHubItemEntity).repo ==
                              repoId) ||
                      t.projectId == repoId),
            )
            .length;

        String keyOf(ProviderProject r) => '${r.accountId}:${r.id}';

        final pinnedRepos = filtered
            .where((r) => pinned.contains(keyOf(r)))
            .toList();
        final unpinnedRepos = filtered
            .where((r) => !pinned.contains(keyOf(r)))
            .toList();

        final recentIds = widget.location.recentScopeIds.toSet();
        final recentRepos = unpinnedRepos
            .where((r) => recentIds.contains(r.id))
            .toList();

        return Column(
          children: [
            ScopeFilterField(
              placeholder: l.filterRepositories,
              onChanged: (val) => setState(() => _filter = val),
            ),
            Expanded(
              child: ScopeListBody(
                groupTitle: l.allRepositories,
                quickScopeRows: [
                  ScopeQuickRow(
                    label: l.allRepositories,
                    icon: LucideIcons.layers300,
                    selected:
                        widget.location.scopeId == null &&
                        widget.location.quickScope == QuickScope.all,
                    onTap: () {
                      ref.read(appNavProvider.notifier).selectScope(null);
                      ref
                          .read(appNavProvider.notifier)
                          .setQuickScope(QuickScope.all);
                    },
                  ),
                  ScopeQuickRow(
                    label: l.reviewRequested,
                    icon: LucideIcons.userCheck300,
                    selected:
                        widget.location.quickScope ==
                        QuickScope.reviewRequested,
                    onTap: () {
                      ref
                          .read(appNavProvider.notifier)
                          .setQuickScope(QuickScope.reviewRequested);
                    },
                  ),
                ],
                pinnedRows: [
                  for (final r in pinnedRepos)
                    ScopeRow(
                      name: r.name,
                      count: openCount(r.id),
                      selected: widget.location.scopeId == r.id,
                      isPinned: true,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(r)),
                      onTap: () =>
                          ref.read(appNavProvider.notifier).selectScope(r.id),
                    ),
                ],
                recentRows: [
                  for (final r in recentRepos)
                    ScopeRow(
                      name: r.name,
                      count: openCount(r.id),
                      selected: widget.location.scopeId == r.id,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(r)),
                      onTap: () =>
                          ref.read(appNavProvider.notifier).selectScope(r.id),
                    ),
                ],
                allRows: [
                  for (final r in unpinnedRepos)
                    ScopeRow(
                      key: ValueKey('github_repo_${r.id}'),
                      name: r.name,
                      count: openCount(r.id),
                      selected: widget.location.scopeId == r.id,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(r)),
                      onTap: () =>
                          ref.read(appNavProvider.notifier).selectScope(r.id),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SidebarStatusRow(label: l.loadingRepositories, loading: true),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SidebarStatusRow(
          label: l.reposUnavailable,
          isError: true,
          onRetry: () => ref.invalidate(githubReposProvider(widget.account.id)),
        ),
      ),
    );
  }
}
