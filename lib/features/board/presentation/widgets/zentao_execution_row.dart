import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/pinned_execution.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../sync/data/sync_service.dart';
import '../board_providers.dart';
import 'sidebar_primitives.dart';

/// A single ZenTao execution (sprint/iteration) leaf under a project node.
/// Tapping it syncs and opens the execution's tasks on the native task board.
class ZenTaoExecutionRow extends ConsumerWidget {
  const ZenTaoExecutionRow({
    super.key,
    required this.execution,
    required this.tickets,
    required this.pinned,
    this.showKindTag = false,
  });

  final ProviderExecution execution;
  final List<Ticket> tickets;
  final bool pinned;

  /// Whether to show the "Task" kind tag (used in the combined Pinned area,
  /// where bugs and tasks sit side by side).
  final bool showKindTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final selected = ref.watch(selectedZenTaoExecutionProvider);
    final syncing = ref.watch(zentaoExecutionSyncingProvider);
    final key = '${execution.accountId}:${execution.id}';
    final active =
        selected?.accountId == execution.accountId &&
        selected?.executionId == execution.id;
    final loading = syncing == key;

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
              if (showKindTag) ...[
                MiniTag(l.taskTag, c.info),
                SizedBox(width: context.spacing.xs),
              ],
              SidebarPinButton(
                pinned: pinned,
                tooltip: pinned ? l.unpinTask : l.pinTask,
                onTap: () => ref
                    .read(appSettingsProvider.notifier)
                    .togglePinnedExecution(
                      PinnedExecution(
                        accountId: execution.accountId,
                        projectId: execution.projectId,
                        executionId: execution.id,
                        name: execution.name,
                      ),
                    ),
              ),
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
    ref.read(settingsOpenProvider.notifier).state = false;
    ref.read(selectedGitLabProjectProvider.notifier).clear();
    ref.read(selectedGitHubRepoProvider.notifier).clear();
    ref.read(selectedZenTaoProductProvider.notifier).clear();
    ref.read(selectedZenTaoExecutionProvider.notifier).select(execution);
    ref.read(viewModeProvider.notifier).set(ViewMode.zentaoTasks);
    ref.read(zentaoExecutionSyncingProvider.notifier).start(execution);
    // Default the task board to the current user's tickets.
    ref
        .read(filterStateProvider.notifier)
        .showMine(ref.read(zentaoSelfHandleProvider(execution.accountId)));
    final res = await getIt<SyncService>().syncExecutionTasks(execution);
    ref.read(zentaoExecutionSyncingProvider.notifier).finish();
    if (res case Err()) {
      messenger.showSnackBar(SnackBar(content: Text(failedMessage)));
    }
  }
}
