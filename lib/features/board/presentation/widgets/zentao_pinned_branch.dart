import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';
import 'zentao_execution_row.dart';
import 'zentao_project_row.dart';

/// The per-account "Pinned" area at the top of a ZenTao node: pinned products
/// (tagged "Bug") and pinned executions (tagged "Task"), lifted out of the Bugs
/// and Tasks groups for quick access. Hidden entirely when nothing is pinned.
class ZenTaoPinnedBranch extends ConsumerWidget {
  const ZenTaoPinnedBranch({
    super.key,
    required this.account,
    required this.tickets,
  });

  final Account account;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinnedProjectKeys = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );
    final pinnedExecutions = ref
        .watch(appSettingsProvider.select((s) => s.pinnedExecutions))
        .where((e) => e.accountId == account.id)
        .toList();

    // Pinned products are resolved against the account's loaded products list;
    // pinned executions carry their own display data, so they need no lookup.
    final products =
        ref.watch(zentaoProductsProvider(account.id)).asData?.value ??
        const <ProviderProduct>[];
    final pinnedProducts = [
      for (final p in products)
        if (pinnedProjectKeys.contains('${p.accountId}:${p.id}')) p,
    ];

    if (pinnedProducts.isEmpty && pinnedExecutions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SidebarPinnedHeader(),
          for (final p in pinnedProducts)
            ZenTaoProjectRow(
              product: p,
              tickets: tickets,
              pinned: true,
              showKindTag: true,
            ),
          for (final e in pinnedExecutions)
            ZenTaoExecutionRow(
              execution: ProviderExecution(
                id: e.executionId,
                name: e.name,
                projectId: e.projectId,
                accountId: e.accountId,
              ),
              tickets: tickets,
              pinned: true,
              showKindTag: true,
            ),
        ],
      ),
    );
  }
}
