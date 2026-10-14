import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../assigned_counts_provider.dart';
import '../board_providers.dart';
import 'github_repo_row.dart';
import 'sidebar_primitives.dart';
import 'sidebar_tree_rows.dart';

/// The children of a GitHub account node: a collapsible "Repositories" group
/// (collapsed by default) listing the repos the account can access. Pinned
/// repos are lifted into the per-account Pinned area ([GitHubPinnedBranch]), so
/// this shows only the unpinned rest.
class GitHubReposBranch extends ConsumerWidget {
  const GitHubReposBranch({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );
    final repos = ref.watch(githubReposProvider(account.id));
    return repos.when(
      data: (items) {
        final rest = [
          for (final r in items)
            if (!pinned.contains('${r.accountId}:${r.id}')) r,
        ];
        return _ReposGroup(accountId: account.id, repos: rest);
      },
      loading: () =>
          SidebarStatusRow(label: l.loadingRepositories, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.reposUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(githubReposProvider(account.id)),
      ),
    );
  }
}

class _ReposGroup extends ConsumerWidget {
  const _ReposGroup({required this.accountId, required this.repos});

  final String accountId;
  final List<ProviderProject> repos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      githubReposExpandedProvider.select((s) => s.contains(accountId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarGroupToggle(
          label: l.githubRepositories,
          expanded: expanded,
          onTap: () =>
              ref.read(githubReposExpandedProvider.notifier).toggle(accountId),
          count: ref.watch(
            assignedCountsProvider.select((c) => c.projects(accountId)),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in repos) GitHubRepoRow(repo: r, pinned: false),
              ],
            ),
          ),
      ],
    );
  }
}
