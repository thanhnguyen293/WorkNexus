import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'board_providers.dart';
import 'widgets/board_view.dart';
import 'widgets/chrome_bar.dart';
import 'widgets/empty_state.dart';
import 'widgets/filter_popover.dart';
import 'widgets/list_view.dart';
import 'widgets/zentao_bug_board_view.dart';
import 'widgets/zentao_task_board_view.dart';

/// The main content area: chrome bar + board/list/empty/skeleton + the
/// advanced-filter popover overlay.
class BoardPage extends ConsumerWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final loading = ref.watch(boardLoadingProvider);
    final mode = ref.watch(viewModeProvider);
    final count = ref.watch(resultCountProvider);
    final advOpen = ref.watch(advFilterOpenProvider);

    Widget body;
    if (loading) {
      body = const BoardSkeleton();
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
