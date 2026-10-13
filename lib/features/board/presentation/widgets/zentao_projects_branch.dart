import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../assigned_counts_provider.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';
import 'sidebar_tree_rows.dart';
import 'zentao_project_row.dart';

/// A ZenTao node's collapsible "Bugs" group (collapsed by default) holding the
/// account's products. Pinned products are lifted out into the per-account
/// Pinned area ([ZenTaoPinnedBranch]), so this shows only the unpinned rest.
class ZenTaoProjectsBranch extends ConsumerWidget {
  const ZenTaoProjectsBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final products = ref.watch(zentaoProductsProvider(account.id));
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );

    String keyOf(ProviderProduct p) => '${p.accountId}:${p.id}';

    return products.when(
      data: (items) {
        final rest = [
          for (final p in items)
            if (!pinned.contains(keyOf(p))) p,
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
        onRetry: () => ref.invalidate(zentaoProductsProvider(account.id)),
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
  final List<ProviderProduct> projects;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final expanded = ref.watch(
      zentaoProjectsExpandedProvider.select((s) => s.contains(accountId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SidebarGroupToggle(
          label: l.bugs,
          expanded: expanded,
          onTap: () => ref
              .read(zentaoProjectsExpandedProvider.notifier)
              .toggle(accountId),
          count: ref.watch(
            assignedCountsProvider.select((c) => c.zentaoBugs(accountId)),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final p in projects)
                  ZenTaoProjectRow(product: p, tickets: tickets, pinned: false),
              ],
            ),
          ),
      ],
    );
  }
}
