import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zentao_board_providers.dart';

/// Child executions rendered when a Product node is expanded in the Bugs popover.
class ZenTaoPopoverProductExecutions extends ConsumerWidget {
  const ZenTaoPopoverProductExecutions({
    super.key,
    required this.accountId,
    required this.product,
    required this.currentExec,
    required this.onSelectExecution,
  });

  final String accountId;
  final ProviderProduct product;
  final ZenTaoExecutionSelection? currentExec;
  final ValueChanged<ProviderExecution> onSelectExecution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final projects =
        ref.watch(zentaoProjectsProvider(accountId)).asData?.value ??
        const <ProviderProject>[];
    final matchedProject = projects.firstWhereOrNull(
      (proj) =>
          proj.name.trim().toLowerCase() == product.name.trim().toLowerCase() ||
          proj.id == product.id,
    );
    final projectId = matchedProject?.id ?? product.id;

    final executionsAsync = ref.watch(
      zentaoExecutionsProvider((accountId: accountId, projectId: projectId)),
    );

    return executionsAsync.when(
      data: (executions) {
        final allExecs = [...executions];
        final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
        for (final t in tickets) {
          if (t.accountId == accountId && t.providerEntity is ZenTaoBugEntity) {
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
                    accountId: accountId,
                  ),
                );
              }
            }
          }
        }

        if (allExecs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(left: 32, top: 2, bottom: 4),
            child: Text(
              'No executions',
              style: context.typography.caption.copyWith(
                color: c.textTertiary,
                fontSize: 11,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final exec in allExecs)
              PopoverBugExecutionItem(
                execution: exec,
                isSelected: currentExec?.executionId == exec.id,
                onTap: () => onSelectExecution(exec),
              ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(left: 32, top: 4, bottom: 4),
        child: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: c.accent),
        ),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(left: 32, top: 2, bottom: 4),
        child: Text(
          'Executions unavailable',
          style: context.typography.caption.copyWith(
            color: c.textTertiary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class PopoverBugExecutionItem extends StatelessWidget {
  const PopoverBugExecutionItem({
    super.key,
    required this.execution,
    required this.isSelected,
    required this.onTap,
  });

  final ProviderExecution execution;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(context.radii.xs),
      child: Container(
        padding: const EdgeInsets.only(left: 28, right: 8, top: 4, bottom: 4),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.xs),
        ),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: isSelected ? c.accent : c.accent.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                execution.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.monoXs.copyWith(
                  color: isSelected ? c.accent : c.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
