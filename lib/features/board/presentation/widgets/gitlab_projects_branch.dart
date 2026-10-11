import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'gitlab_project_row.dart';
import 'sidebar_primitives.dart';
import 'sidebar_tree_rows.dart';

/// The children of a GitLab account node: a collapsible "Projects" group
/// (collapsed by default) listing the projects the account is a member of.
/// Pinned projects are lifted into the per-account Pinned area
/// ([GitLabPinnedBranch]), so this shows only the unpinned rest.
class GitLabProjectsBranch extends ConsumerWidget {
  const GitLabProjectsBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );
    final projects = ref.watch(gitlabProjectsProvider(account.id));
    return projects.when(
      data: (items) {
        final rest = [
          for (final p in items)
            if (!pinned.contains('${p.accountId}:${p.id}')) p,
        ];
        return _ProjectsGroup(
          accountId: account.id,
          projects: rest,
          tickets: tickets,
        );
      },
      loading: () => SidebarStatusRow(label: l.loadingProjects, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.projectsUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(gitlabProjectsProvider(account.id)),
      ),
    );
  }
}

class _ProjectsGroup extends ConsumerWidget {
  const _ProjectsGroup({
    required this.accountId,
    required this.projects,
    required this.tickets,
  });

  final String accountId;
  final List<ProviderProject> projects;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      gitlabProjectsExpandedProvider.select((s) => s.contains(accountId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarGroupToggle(
          label: l.projects,
          expanded: expanded,
          onTap: () => ref
              .read(gitlabProjectsExpandedProvider.notifier)
              .toggle(accountId),
          count: projects.length,
        ),
        if (expanded)
          SidebarTreeBranch(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in projects)
                  GitLabProjectRow(project: p, tickets: tickets, pinned: false),
              ],
            ),
          ),
      ],
    );
  }
}
