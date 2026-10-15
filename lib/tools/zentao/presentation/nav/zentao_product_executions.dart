import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../providers/zentao_board_providers.dart';
import '../widgets/zentao_execution_row.dart';

/// Child executions under a Product node in the ZenTao Bugs navigation tree.
class ZentaoProductExecutions extends ConsumerWidget {
  const ZentaoProductExecutions({
    super.key,
    required this.account,
    required this.product,
    required this.tickets,
  });

  final Account account;
  final ProviderProduct product;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final projects =
        ref.watch(zentaoProjectsProvider(account.id)).asData?.value ??
        const <ProviderProject>[];
    final matchedProject = projects.firstWhereOrNull(
      (proj) =>
          proj.name.trim().toLowerCase() == product.name.trim().toLowerCase() ||
          proj.id == product.id,
    );
    final projectId = matchedProject?.id ?? product.id;

    final executionsAsync = ref.watch(
      zentaoExecutionsProvider((accountId: account.id, projectId: projectId)),
    );
    final pinnedKeys = {
      for (final e in ref.watch(
        appSettingsProvider.select((s) => s.pinnedExecutions),
      ))
        e.key,
    };

    return executionsAsync.when(
      data: (executions) {
        final allExecs = [...executions];
        for (final t in tickets) {
          if (t.accountId == account.id &&
              t.providerEntity is ZenTaoBugEntity) {
            final bug = t.providerEntity as ZenTaoBugEntity;
            if ((bug.product == product.id ||
                    bug.productName == product.name) &&
                bug.execution != null &&
                bug.execution!.isNotEmpty) {
              if (!allExecs.any((e) => e.id == bug.execution)) {
                allExecs.add(
                  ProviderExecution(
                    id: bug.execution!,
                    name: bug.executionName ?? 'Execution ${bug.execution}',
                    projectId: projectId,
                    accountId: account.id,
                  ),
                );
              }
            }
          }
        }

        if (allExecs.isEmpty) {
          return SidebarStatusRow(label: l.noExecutions);
        }

        int executionBugCount(String executionId) => tickets
            .where(
              (t) =>
                  t.accountId == account.id &&
                  t.status != UnifiedStatus.done &&
                  switch (t.providerEntity) {
                    ZenTaoBugEntity(:final execution) =>
                      execution == executionId,
                    _ => false,
                  },
            )
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final execution in allExecs)
              ZenTaoExecutionRow(
                key: ValueKey('prod_exec_${execution.id}'),
                execution: execution,
                pinned: pinnedKeys.contains('${account.id}:${execution.id}'),
                countOverride: executionBugCount(execution.id),
                onTap: () {
                  ref.read(appNavProvider.notifier).selectScope(product.id);
                  ref
                      .read(selectedZenTaoProductProvider.notifier)
                      .select(product);
                  ref
                      .read(selectedZenTaoExecutionProvider.notifier)
                      .select(execution);
                  ref
                      .read(filterStateProvider.notifier)
                      .openBoard(ref.read(boardKeyProvider));
                },
              ),
          ],
        );
      },
      loading: () =>
          SidebarStatusRow(label: l.loadingExecutions, loading: true),
      error: (_, _) => SidebarStatusRow(
        label: l.executionsUnavailable,
        isError: true,
        onRetry: () => ref.invalidate(
          zentaoExecutionsProvider((
            accountId: account.id,
            projectId: projectId,
          )),
        ),
      ),
    );
  }
}
