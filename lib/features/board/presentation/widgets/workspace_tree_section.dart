import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/entities/workspace.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import 'sidebar_primitives.dart';
import 'zentao_projects_branch.dart';

/// The sources tree: `WORKSPACE → workspace → ZenTao → [pinned, Projects]`.
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
        SidebarSectionLabel(l.workspace),
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
              a.providerType == ProviderType.zentao,
        )
        .toList();
    final count = tickets
        .where(
          (tk) => lookups.accounts[tk.accountId]?.workspaceId == workspace.id,
        )
        .length;

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Structural header — intentionally not tappable.
          Container(
            height: 33,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                WorkspaceBadge(
                  Color(workspace.colorValue),
                  workspace.shortCode,
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    workspace.isPersonal ? l.personal : workspace.name,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: context.typography.monoSm.copyWith(
                    color: c.textTertiary,
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
                    _ZenTaoNode(account: a, tickets: tickets),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ZenTaoNode extends StatelessWidget {
  const _ZenTaoNode({required this.account, required this.tickets});

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final count = tickets.where((tk) => tk.accountId == account.id).length;

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 31,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            child: Row(
              children: [
                const ProviderBadge(ProviderType.zentao),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Text(
                    ProviderType.zentao.displayName,
                    style: context.typography.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
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
            child: ZenTaoProjectsBranch(account: account, tickets: tickets),
          ),
        ],
      ),
    );
  }
}
