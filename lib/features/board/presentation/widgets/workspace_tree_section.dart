import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import 'github_pinned_branch.dart';
import 'github_repos_branch.dart';
import 'gitlab_pinned_branch.dart';
import 'gitlab_projects_branch.dart';
import 'provider_mine_row.dart';
import 'sidebar_primitives.dart';
import 'zentao_executions_branch.dart';
import 'zentao_pinned_branch.dart';
import 'zentao_projects_branch.dart';

/// The sources tree: `WORKSPACE → workspace → ZenTao → [Pinned, Bugs, Tasks]`.
/// The workspace node is structural (not tappable); it groups its ZenTao
/// accounts, whose projects hang beneath.
class WorkspaceTreeSection extends ConsumerWidget {
  const WorkspaceTreeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
    final lookups = ref.watch(lookupsProvider);
    final workspaces = lookups.workspaces.values.toList();
    if (workspaces.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l.workspace,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.xs),
        ),
        for (final w in workspaces)
          _WorkspaceNode(workspace: w, tickets: tickets, lookups: lookups),
      ],
    );
  }
}

class _WorkspaceNode extends StatelessWidget {
  const _WorkspaceNode({
    required this.workspace,
    required this.tickets,
    required this.lookups,
  });

  final Workspace workspace;
  final List<Ticket> tickets;
  final Lookups lookups;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final accounts = lookups.accounts.values
        .where(
          (a) =>
              a.workspaceId == workspace.id &&
              (a.providerType == ProviderType.zentao ||
                  a.providerType == ProviderType.gitlab ||
                  a.providerType == ProviderType.github),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Structural header — intentionally not tappable.
          Container(
            height: context.sizes.controlMd,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                WorkspaceBadge(
                  Color(workspace.colorValue),
                  workspace.shortCode,
                  iconKey: workspace.iconKey,
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    workspace.isPersonal ? l.personal : workspace.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (accounts.isNotEmpty)
            SidebarTreeBranch(
              strong: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in accounts)
                    _AccountNode(account: a, tickets: tickets),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Picks the branches an account shows by its provider.
class _AccountNode extends StatelessWidget {
  const _AccountNode({required this.account, required this.tickets});

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) => switch (account.providerType) {
    ProviderType.gitlab => _ProviderNode(
      provider: ProviderType.gitlab,
      children: [
        ProviderMineRow(account: account),
        GitLabPinnedBranch(account: account, tickets: tickets),
        GitLabProjectsBranch(account: account, tickets: tickets),
      ],
    ),
    ProviderType.github => _ProviderNode(
      provider: ProviderType.github,
      count: tickets.where((tk) => tk.accountId == account.id).length,
      children: [
        ProviderMineRow(account: account),
        GitHubPinnedBranch(account: account, tickets: tickets),
        GitHubReposBranch(account: account, tickets: tickets),
      ],
    ),
    _ => _ProviderNode(
      provider: ProviderType.zentao,
      children: [
        ZenTaoPinnedBranch(account: account, tickets: tickets),
        ZenTaoProjectsBranch(account: account, tickets: tickets),
        ZenTaoExecutionsBranch(account: account, tickets: tickets),
      ],
    ),
  };
}

/// One connected account in a workspace: its provider header over the
/// provider's own branches ([children]). [count] adds a ticket tally.
class _ProviderNode extends StatelessWidget {
  const _ProviderNode({
    required this.provider,
    required this.children,
    this.count,
  });

  final ProviderType provider;
  final List<Widget> children;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = this.count;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: context.sizes.controlMd,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                ProviderBadge(provider),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Text(
                    provider.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: context.typography.monoXs.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          SidebarTreeBranch(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
