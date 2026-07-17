import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../board_providers.dart';
import 'account_row.dart';
import 'sidebar_primitives.dart';

const _providerOrder = [
  ProviderType.github,
  ProviderType.gitlab,
  ProviderType.jira,
  ProviderType.zentao,
];

/// The "Sources" tree: workspace → provider → account → project.
class SourcesSection extends ConsumerWidget {
  const SourcesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final filter = ref.watch(filterStateProvider);
    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
    final lookups = ref.watch(lookupsProvider);

    final wsIds = filter.workspaceId == 'all'
        ? lookups.workspaces.keys.toList()
        : [filter.workspaceId];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSectionLabel(l.sources),
        for (final wsId in wsIds)
          _WorkspaceGroup(wsId: wsId, tickets: tickets, lookups: lookups),
      ],
    );
  }
}

class _WorkspaceGroup extends ConsumerWidget {
  const _WorkspaceGroup({
    required this.wsId,
    required this.tickets,
    required this.lookups,
  });
  final String wsId;
  final List<Ticket> tickets;
  final Lookups lookups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ws = lookups.workspaces[wsId];
    if (ws == null) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final wsAccounts = lookups.accounts.values
        .where((a) => a.workspaceId == wsId)
        .toList();
    final wsTickets = tickets.where(
      (tk) => lookups.accounts[tk.accountId]?.workspaceId == wsId,
    );
    final providers = _providerOrder
        .where((p) => wsAccounts.any((a) => a.providerType == p))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                ref.read(filterStateProvider.notifier).setWorkspace(wsId),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.xs,
                context.spacing.sm,
                context.spacing.xs,
                context.spacing.sm,
              ),
              child: Row(
                children: [
                  WorkspaceBadge(Color(ws.colorValue), ws.shortCode, big: true),
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: Text(
                      ws.isPersonal ? l.personal : ws.name,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${wsTickets.length}',
                    style: context.typography.monoXs.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final p in providers)
            _ProviderGroup(
              wsId: wsId,
              provider: p,
              accounts: wsAccounts.where((a) => a.providerType == p).toList(),
              tickets: tickets,
              lookups: lookups,
            ),
        ],
      ),
    );
  }
}

class _ProviderGroup extends ConsumerWidget {
  const _ProviderGroup({
    required this.wsId,
    required this.provider,
    required this.accounts,
    required this.tickets,
    required this.lookups,
  });
  final String wsId;
  final ProviderType provider;
  final List<Account> accounts;
  final List<Ticket> tickets;
  final Lookups lookups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final accIds = accounts.map((a) => a.id).toSet();
    final connTickets = tickets.where(
      (tk) =>
          lookups.accounts[tk.accountId]?.workspaceId == wsId &&
          accIds.contains(tk.accountId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () =>
              ref.read(filterStateProvider.notifier).toggleProvider(provider),
          borderRadius: BorderRadius.circular(context.radii.sm),
          child: Container(
            height: 29,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
            decoration: BoxDecoration(
              color: filter.providers.contains(provider)
                  ? c.selectionFill
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(context.radii.sm),
            ),
            child: Row(
              children: [
                ProviderBadge(provider),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Text(
                    provider.displayName,
                    style: context.typography.meta.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${connTickets.length}',
                  style: context.typography.monoXs.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: context.spacing.md,
            top: context.spacing.xxs,
            bottom: context.spacing.xxs,
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: c.borderStrong)),
            ),
            padding: EdgeInsets.only(left: context.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in accounts)
                  AccountRow(account: a, tickets: tickets, lookups: lookups),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
