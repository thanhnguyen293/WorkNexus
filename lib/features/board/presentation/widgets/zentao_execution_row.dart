import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/pinned_execution.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../assigned_counts_provider.dart';
import '../board_providers.dart';
import '../util/open_execution_board.dart';
import 'sidebar_primitives.dart';

/// A single ZenTao execution (sprint/iteration) leaf under a project node.
/// Tapping it syncs and opens the execution's tasks on the native task board.
class ZenTaoExecutionRow extends ConsumerWidget {
  const ZenTaoExecutionRow({
    super.key,
    required this.execution,
    required this.pinned,
    this.showKindTag = false,
  });

  final ProviderExecution execution;
  final bool pinned;

  /// Whether to show the "Task" kind tag (used in the combined Pinned area,
  /// where bugs and tasks sit side by side).
  final bool showKindTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      assignedCountsProvider.select(
        (c) => c.zentaoExecution(execution.accountId, execution.id),
      ),
    );
    final c = context.colors;
    final l = AppL10n.of(context);
    final selected = ref.watch(selectedZenTaoExecutionProvider);
    final active =
        selected?.accountId == execution.accountId &&
        selected?.executionId == execution.id;
    // While this execution is the open board and its first pages are loading.
    final loading = active && ref.watch(zentaoTaskSliceProvider).isLoading;

    return Opacity(
      opacity: loading ? 0.48 : 1,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: loading
            ? null
            : () => openExecutionBoard(context, ref, execution),
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          height: context.sizes.controlSm,
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
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (loading) ...[
                const SidebarSyncIndicator(),
                SizedBox(width: context.spacing.xxs),
              ],
              if (showKindTag) ...[
                MiniTag(l.taskTag, c.info),
                SizedBox(width: context.spacing.xs),
              ],
              if (count > 0) ...[
                SidebarCountBadge(count),
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
}
