import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../l10n/app_localizations.dart';
import 'board_providers.dart';
import 'board_refresh.dart';
import 'widgets/board_view.dart';
import 'widgets/chrome_bar.dart';
import 'widgets/empty_state.dart';
import 'widgets/github_board_view.dart';
import 'widgets/github_tabs.dart';
import 'widgets/gitlab_board_view.dart';
import 'widgets/gitlab_tabs.dart';
import 'widgets/welcome_view.dart';
import 'widgets/zentao_bug_board_view.dart';
import 'widgets/zentao_bug_table_view.dart';
import 'widgets/zentao_bug_tabs.dart';
import 'widgets/zentao_task_board_view.dart';
import 'widgets/zentao_task_table_view.dart';

/// The main content area: chrome bar (with the board tabs and the filter
/// popover's button) over the board / table / empty state / skeleton.
class BoardPage extends ConsumerWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mode = ref.watch(viewModeProvider);

    // Fresh launch / no source picked yet: show the minimal welcome screen with
    // no toolbar and no board. Selecting a source from the sidebar switches the
    // view mode and brings the board (and its chrome) in.
    if (mode == ViewMode.home) {
      return ColoredBox(color: c.background, child: const WelcomeView());
    }

    final loading = ref.watch(boardLoadingProvider);
    final count = ref.watch(resultCountProvider);
    final table =
        ref.watch(appSettingsProvider.select((s) => s.boardLayout)) ==
        BoardLayout.table;

    // The active ZenTao bug tab's fetch status (null off the bug board). Each tab
    // is its own server call, so a tab switch re-enters loading here.
    final bugSlice = mode == ViewMode.zentaoBugs
        ? ref.watch(zentaoBugSliceProvider)
        : null;
    // The account-wide "my MRs/PRs" boards reuse the GitLab/GitHub views but
    // fetch a different slice and hide the kind tabs (they are MR/PR-only).
    final gitlabMine =
        mode == ViewMode.gitlab &&
        (ref.watch(selectedGitLabProjectProvider)?.mine ?? false);
    final githubMine =
        mode == ViewMode.github &&
        (ref.watch(selectedGitHubRepoProvider)?.mine ?? false);
    final gitlabSlice = mode == ViewMode.gitlab
        ? (gitlabMine
              ? ref.watch(gitlabMineSliceProvider)
              : ref.watch(gitlabItemsSliceProvider))
        : null;
    final githubSlice = mode == ViewMode.github
        ? (githubMine
              ? ref.watch(githubMineSliceProvider)
              : ref.watch(githubItemsSliceProvider))
        : null;
    final taskSlice = mode == ViewMode.zentaoTasks
        ? ref.watch(zentaoTaskSliceProvider)
        : null;

    // The active board's view tabs, rendered inline on the ChromeBar toolbar
    // row. The account-wide "my MRs/PRs" boards are MR/PR-only, so no tabs.
    final Widget? boardTabs;
    if (mode == ViewMode.zentaoBugs) {
      boardTabs = const ZenTaoBugTabs();
    } else if (mode == ViewMode.gitlab && !gitlabMine) {
      boardTabs = const GitLabTabs();
    } else if (mode == ViewMode.github && !githubMine) {
      boardTabs = const GitHubTabs();
    } else {
      boardTabs = null;
    }
    // While a just-opened tab/execution/project is still fetching and nothing is
    // cached yet, show the skeleton instead of a momentary empty state.
    final showSkeleton =
        loading ||
        ((bugSlice?.isLoading ?? false) && count == 0) ||
        ((gitlabSlice?.isLoading ?? false) && count == 0) ||
        ((githubSlice?.isLoading ?? false) && count == 0) ||
        ((taskSlice?.isLoading ?? false) && count == 0);

    // A slice fetch that fails only blocks the board when nothing is cached yet
    // (offline-first: with cached tickets the board renders from the DB and the
    // stale slice quietly reconciles once connectivity returns).
    Widget body;
    if (showSkeleton) {
      body = const BoardSkeleton();
    } else if (bugSlice != null && bugSlice.hasError && count == 0) {
      body = _SliceError(title: AppL10n.of(context).bugTabLoadFailed);
    } else if (taskSlice != null && taskSlice.hasError && count == 0) {
      body = _SliceError(title: AppL10n.of(context).executionOpenFailed);
    } else if (gitlabSlice != null && gitlabSlice.hasError && count == 0) {
      body = _SliceError(title: AppL10n.of(context).gitlabItemsLoadFailed);
    } else if (githubSlice != null && githubSlice.hasError && count == 0) {
      body = _SliceError(title: AppL10n.of(context).githubItemsLoadFailed);
    } else if (count == 0 &&
        !(mode == ViewMode.zentaoBugs && ref.watch(zentaoBugHasMoreProvider)) &&
        !(mode == ViewMode.zentaoTasks &&
            ref.watch(zentaoTaskHasMoreProvider))) {
      // A paged board whose columns can load more stays up, so they can.
      body = const EmptyState();
    } else {
      body = switch (mode) {
        // Unreachable — home returns early above — but keeps the switch total.
        ViewMode.home => const WelcomeView(),
        ViewMode.board => const BoardView(),
        ViewMode.zentaoBugs =>
          table ? const ZenTaoBugTableView() : const ZenTaoBugBoardView(),
        ViewMode.zentaoTasks =>
          table ? const ZenTaoTaskTableView() : const ZenTaoTaskBoardView(),
        ViewMode.gitlab => const GitLabBoardView(),
        ViewMode.github => const GitHubBoardView(),
      };
    }

    return ColoredBox(
      color: c.background,
      child: Column(
        // Full width for the body: a sideways-scrolling board shrinks to its
        // columns under a loose width, and would then sit centred.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChromeBar(tabs: boardTabs),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Shown when the active board slice's fetch fails and nothing is cached (rule
/// 11.3: render the error, don't swallow it). Retry runs the toolbar's own
/// refresh; the tab strip stays visible above it.
class _SliceError extends ConsumerWidget {
  const _SliceError({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppStateView.error(
      title: title,
      onRetry: () => ref.read(refreshBoardProvider)(),
    );
  }
}
