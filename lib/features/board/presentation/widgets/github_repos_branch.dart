import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'github_repo_row.dart';
import 'sidebar_primitives.dart';

/// The children of a GitHub account node: a collapsible "Repositories" group
/// (collapsed by default) listing the repos the account can access.
class GitHubReposBranch extends ConsumerWidget {
  const GitHubReposBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final repos = ref.watch(githubReposProvider(account.id));
    return repos.when(
      data: (items) =>
          _ReposGroup(accountId: account.id, repos: items, tickets: tickets),
      loading: () => _MutedRow(label: l.loadingRepositories),
      error: (_, _) => _MutedRow(label: l.reposUnavailable),
    );
  }
}

class _ReposGroup extends ConsumerWidget {
  const _ReposGroup({
    required this.accountId,
    required this.repos,
    required this.tickets,
  });

  final String accountId;
  final List<ProviderProject> repos;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      githubReposExpandedProvider.select((s) => s.contains(accountId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              ref.read(githubReposExpandedProvider.notifier).toggle(accountId),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: 27,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 14,
                  color: c.textTertiary,
                ),
                SizedBox(width: context.spacing.xs),
                Expanded(
                  child: Text(
                    l.githubRepositories,
                    style: context.typography.mono.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in repos) GitHubRepoRow(repo: r, tickets: tickets),
              ],
            ),
          ),
      ],
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 27,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: c.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mono.copyWith(
                fontWeight: FontWeight.w500,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
