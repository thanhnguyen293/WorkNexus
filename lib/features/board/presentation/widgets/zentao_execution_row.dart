import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../board_providers.dart';

/// A single ZenTao execution (sprint/iteration) leaf under a project node.
/// Tapping it syncs and opens the execution's tasks on the native task board.
class ZenTaoExecutionRow extends ConsumerWidget {
  const ZenTaoExecutionRow({
    super.key,
    required this.execution,
    required this.tickets,
  });

  final ProviderExecution execution;
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(selectedZenTaoExecutionProvider);
    final syncing = ref.watch(zentaoExecutionSyncingProvider);
    final key = '${execution.accountId}:${execution.id}';
    final active =
        selected?.accountId == execution.accountId &&
        selected?.executionId == execution.id;
    final loading = syncing == key;
    final count = tickets
        .where(
          (t) =>
              t.accountId == execution.accountId &&
              t.labels.contains('zentao-execution:${execution.id}'),
        )
        .length;

    return Opacity(
      opacity: loading ? 0.48 : 1,
      child: InkWell(
        onTap: loading ? null : () => _select(context, ref),
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          height: 27,
          padding: EdgeInsets.only(
            left: context.spacing.sm,
            right: context.spacing.xxs,
          ),
          decoration: BoxDecoration(
            color: active ? c.selectionFill : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: c.info,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  execution.name,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.mono.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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
              SizedBox(width: context.spacing.xxs),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref) async {
    // Switch to this execution's task board immediately, then stream its tasks
    // into the DB, which the board reads reactively. Selecting a task board and
    // a bug board are mutually exclusive, so clear the product selection first.
    // Capture before the await so no BuildContext is used across the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final failedMessage = AppL10n.of(context).executionOpenFailed;
    ref.read(selectedGitLabProjectProvider.notifier).clear();
    ref.read(selectedZenTaoProductProvider.notifier).clear();
    ref.read(selectedZenTaoExecutionProvider.notifier).select(execution);
    ref.read(viewModeProvider.notifier).set(ViewMode.zentaoTasks);
    ref.read(zentaoExecutionSyncingProvider.notifier).start(execution);
    final res = await getIt<SyncService>().syncExecutionTasks(execution);
    ref.read(zentaoExecutionSyncingProvider.notifier).finish();
    if (res case Err()) {
      messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
    }
  }
}
