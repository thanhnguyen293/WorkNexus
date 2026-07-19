import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/app_localizations.dart';
import 'board_providers.dart';
import 'widgets/board_view.dart';
import 'widgets/chrome_bar.dart';
import 'widgets/empty_state.dart';
import 'widgets/filter_popover.dart';
import 'widgets/list_view.dart';
import 'widgets/zentao_bug_board_view.dart';
import 'widgets/zentao_bug_tabs.dart';
import 'widgets/zentao_task_board_view.dart';

/// The main content area: chrome bar + (ZenTao bug tabs) + board/list/empty/
/// skeleton + the advanced-filter popover overlay.
class BoardPage extends ConsumerWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final loading = ref.watch(boardLoadingProvider);
    final mode = ref.watch(viewModeProvider);
    final count = ref.watch(resultCountProvider);
    final advOpen = ref.watch(advFilterOpenProvider);

    // The active ZenTao bug tab's fetch status (null off the bug board). Each tab
    // is its own server call, so a tab switch re-enters loading here.
    final bugSlice = mode == ViewMode.zentaoBugs
        ? ref.watch(zentaoBugTabSliceProvider)
        : null;
    final executionSyncing = ref.watch(zentaoExecutionSyncingProvider) != null;
    // While a just-opened tab/execution is still fetching and nothing is cached
    // yet, show the skeleton instead of a momentary empty state.
    final showSkeleton =
        loading ||
        ((bugSlice?.isLoading ?? false) && count == 0) ||
        (executionSyncing && count == 0 && mode == ViewMode.zentaoTasks);

    Widget body;
    if (showSkeleton) {
      body = const BoardSkeleton();
    } else if (bugSlice != null && bugSlice.hasError) {
      body = const _BugTabError();
    } else if (count == 0) {
      body = const EmptyState();
    } else {
      body = switch (mode) {
        ViewMode.board => const BoardView(),
        ViewMode.zentaoBugs => const ZenTaoBugBoardView(),
        ViewMode.zentaoTasks => const ZenTaoTaskBoardView(),
        ViewMode.list => const TaskListView(),
      };
    }

    return ColoredBox(
      color: c.background,
      child: Column(
        children: [
          const ChromeBar(),
          if (mode == ViewMode.zentaoBugs) const ZenTaoBugTabs(),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                if (advOpen) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () =>
                          ref.read(advFilterOpenProvider.notifier).state =
                              false,
                    ),
                  ),
                  Positioned(
                    top: context.spacing.sm,
                    left: context.spacing.xl2,
                    child: const FilterPopover(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the bug board when the active tab's fetch fails (rule 11.3: render
/// the error, don't swallow it). The tab strip stays visible so the user can
/// retry by switching tabs.
class _BugTabError extends StatelessWidget {
  const _BugTabError();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 28, color: c.textTertiary),
          SizedBox(height: context.spacing.md),
          Text(
            l.bugTabLoadFailed,
            style: context.typography.bodySm.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
