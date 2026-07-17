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
import 'zentao_type_row.dart';

const _providerOrder = [
  ProviderType.github,
  ProviderType.gitlab,
  ProviderType.jira,
  ProviderType.zentao,
];

/// The "Sources" tree: provider → workspace/account → project.
class SourcesSection extends ConsumerWidget {
  const SourcesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final filter = ref.watch(filterStateProvider);
    final tickets =
        ref.watch(ticketsProvider).asData?.value ?? const <Ticket>[];
    final lookups = ref.watch(lookupsProvider);

    final scopedAccounts = lookups.accounts.values
        .where(
          (account) =>
              filter.workspaceId == 'all' ||
              account.workspaceId == filter.workspaceId,
        )
        .toList();
    final providers = _providerOrder
        .where(
          (provider) => scopedAccounts.any((a) => a.providerType == provider),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarSectionLabel(l.sources),
        for (final provider in providers)
          _ProviderGroup(
            provider: provider,
            accounts: scopedAccounts
                .where((account) => account.providerType == provider)
                .toList(),
            tickets: tickets,
            lookups: lookups,
            showWorkspaceGroups: filter.workspaceId == 'all',
          ),
      ],
    );
  }
}

class _ProviderGroup extends ConsumerWidget {
  const _ProviderGroup({
    required this.provider,
    required this.accounts,
    required this.tickets,
    required this.lookups,
    required this.showWorkspaceGroups,
  });
  final ProviderType provider;
  final List<Account> accounts;
  final List<Ticket> tickets;
  final Lookups lookups;
  final bool showWorkspaceGroups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(filterStateProvider);
    final accIds = accounts.map((a) => a.id).toSet();
    final connTickets = tickets.where((tk) => accIds.contains(tk.accountId));
    final zentaoBugCount = connTickets
        .where((tk) => (tk.externalType ?? '').toLowerCase() == 'bug')
        .length;
    final zentaoTaskCount = connTickets
        .where((tk) => (tk.externalType ?? '').toLowerCase() == 'task')
        .length;
    final workspaceIds = {
      for (final account in accounts) account.workspaceId,
    }.toList();
    final isZenTao = provider == ProviderType.zentao;

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: isZenTao
                ? null
                : () => ref
                      .read(filterStateProvider.notifier)
                      .toggleProvider(provider),
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Container(
              height: 31,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
              decoration: BoxDecoration(
                color: !isZenTao && filter.providers.contains(provider)
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
                      style: context.typography.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
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
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.borderStrong)),
              ),
              padding: EdgeInsets.only(left: context.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isZenTao) ...[
                    ZenTaoTypeRow(
                      label: 'Bugs',
                      count: zentaoBugCount,
                      active:
                          ref.watch(viewModeProvider) == ViewMode.zentaoBugs,
                      onTap: () => ref
                          .read(viewModeProvider.notifier)
                          .set(ViewMode.zentaoBugs),
                    ),
                    ZenTaoTypeRow(
                      label: 'Tasks',
                      count: zentaoTaskCount,
                      active:
                          ref.watch(viewModeProvider) == ViewMode.zentaoTasks,
                      onTap: () => ref
                          .read(viewModeProvider.notifier)
                          .set(ViewMode.zentaoTasks),
                    ),
                  ],
                  if (showWorkspaceGroups)
                    for (final wsId in workspaceIds)
                      _WorkspaceBranch(
                        wsId: wsId,
                        accounts: accounts
                            .where((a) => a.workspaceId == wsId)
                            .toList(),
                        tickets: tickets,
                        lookups: lookups,
                      )
                  else
                    for (final account in accounts)
                      AccountRow(
                        account: account,
                        tickets: tickets,
                        lookups: lookups,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceBranch extends ConsumerWidget {
  const _WorkspaceBranch({
    required this.wsId,
    required this.accounts,
    required this.tickets,
    required this.lookups,
  });

  final String wsId;
  final List<Account> accounts;
  final List<Ticket> tickets;
  final Lookups lookups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final ws = lookups.workspaces[wsId];
    if (ws == null) return const SizedBox.shrink();
    final accountIds = accounts.map((account) => account.id).toSet();
    final count = tickets
        .where((tk) => accountIds.contains(tk.accountId))
        .length;

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () =>
                ref.read(filterStateProvider.notifier).setWorkspace(wsId),
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Container(
              height: 27,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.sm),
              child: Row(
                children: [
                  WorkspaceBadge(Color(ws.colorValue), ws.shortCode),
                  SizedBox(width: context.spacing.sm),
                  Expanded(
                    child: Text(
                      ws.isPersonal ? l.personal : ws.name,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.meta.copyWith(
                        fontWeight: FontWeight.w600,
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
          ),
          Padding(
            padding: EdgeInsets.only(left: context.spacing.md),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.only(left: context.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final account in accounts)
                    AccountRow(
                      account: account,
                      tickets: tickets,
                      lookups: lookups,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
