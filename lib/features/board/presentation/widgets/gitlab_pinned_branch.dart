import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../board_providers.dart';
import 'gitlab_project_row.dart';
import 'provider_pinned_projects.dart';

/// The per-account "Pinned" area of a GitLab node: the account's pinned
/// projects, resolved against its loaded projects list and lifted above the
/// collapsible Projects group. Hidden when nothing is pinned.
class GitLabPinnedBranch extends ConsumerWidget {
  const GitLabPinnedBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedKeys = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );
    final projects =
        ref.watch(gitlabProjectsProvider(account.id)).asData?.value ??
        const <ProviderProject>[];
    final pinned = [
      for (final p in projects)
        if (pinnedKeys.contains('${p.accountId}:${p.id}')) p,
    ];
    return ProviderPinnedProjects(
      pinned: pinned,
      rowBuilder: (p) =>
          GitLabProjectRow(project: p, tickets: tickets, pinned: true),
    );
  }
}
