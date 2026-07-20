import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../board_providers.dart';
import 'github_repo_row.dart';
import 'provider_pinned_projects.dart';

/// The per-account "Pinned" area of a GitHub node: the account's pinned repos,
/// resolved against its loaded repos list and lifted above the collapsible
/// Repositories group. Hidden when nothing is pinned.
class GitHubPinnedBranch extends ConsumerWidget {
  const GitHubPinnedBranch({
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
    final repos =
        ref.watch(githubReposProvider(account.id)).asData?.value ??
        const <ProviderProject>[];
    final pinned = [
      for (final r in repos)
        if (pinnedKeys.contains('${r.accountId}:${r.id}')) r,
    ];
    return ProviderPinnedProjects(
      pinned: pinned,
      rowBuilder: (r) => GitHubRepoRow(repo: r, tickets: tickets, pinned: true),
    );
  }
}
