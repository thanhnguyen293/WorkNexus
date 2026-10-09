import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_providers.dart';
import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/ticket.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/error/result.dart';
import '../../../core/util/synthetic_labels.dart';
import '../domain/entities/board_model.dart';
import '../domain/usecases/build_board.dart';
import '../domain/usecases/build_github_issue_board.dart';
import '../domain/usecases/build_github_pr_board.dart';
import '../domain/usecases/build_gitlab_issue_board.dart';
import '../domain/usecases/build_gitlab_mr_board.dart';
import '../domain/usecases/build_list.dart';
import '../domain/usecases/build_zentao_bug_board.dart';
import '../domain/usecases/build_zentao_task_board.dart';
import '../domain/usecases/derive_board_facets.dart';
import '../domain/usecases/filter_tickets.dart';
import '../domain/usecases/scope_provider_tickets.dart';
import '../domain/value_objects/github_item_kind.dart';
import '../domain/value_objects/gitlab_item_kind.dart';
import '../domain/value_objects/zentao_bug_browse_type.dart';
import 'filter_providers.dart';

// The filter controller and the board-loading pulse live in their own files to
// keep this one from growing further; re-exported so the many widgets that
// already import `board_providers.dart` keep a single import for board state.
export 'board_loading_provider.dart';
export 'filter_providers.dart';

part 'board_providers_zentao.dart';
part 'board_providers_gitlab.dart';
part 'board_providers_github.dart';
part 'board_providers_derived.dart';

/// [home] is the launch state: no source is selected yet, so the main area
/// shows the welcome screen instead of a board. The user opens a real view by
/// picking a source from the sidebar.
enum ViewMode { home, board, zentaoBugs, zentaoTasks, gitlab, github, list }

class ZenTaoProductSelection {
  const ZenTaoProductSelection({
    required this.accountId,
    required this.productId,
    required this.productName,
  });

  final String accountId;
  final String productId;
  final String productName;
}

final viewModeProvider = NotifierProvider<ViewModeController, ViewMode>(
  ViewModeController.new,
);

class ViewModeController extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.home;
  void set(ViewMode m) => state = m;
}

/// A stable identity for the board on screen — the key its filter is remembered
/// under by [FilterController.openBoard]. Two boards share a key only when they
/// are the same board; the view tabs within one board (bug browse type,
/// issues/MRs) deliberately do not, so switching tabs keeps your filter.
final boardKeyProvider = Provider<String>((ref) {
  switch (ref.watch(viewModeProvider)) {
    case ViewMode.home:
      return 'home';
    case ViewMode.board:
      return 'board';
    case ViewMode.list:
      return 'list';
    case ViewMode.zentaoBugs:
      final product = ref.watch(selectedZenTaoProductProvider);
      return product == null
          ? 'zentao:bugs'
          : 'zentao:bugs:${product.accountId}:${product.productId}';
    case ViewMode.zentaoTasks:
      final execution = ref.watch(selectedZenTaoExecutionProvider);
      return execution == null
          ? 'zentao:tasks'
          : 'zentao:tasks:${execution.accountId}:${execution.executionId}';
    case ViewMode.gitlab:
      final project = ref.watch(selectedGitLabProjectProvider);
      if (project == null) return 'gitlab';
      return project.mine
          ? 'gitlab:mine:${project.accountId}'
          : 'gitlab:${project.accountId}:${project.projectId}';
    case ViewMode.github:
      final repo = ref.watch(selectedGitHubRepoProvider);
      if (repo == null) return 'github';
      return repo.mine
          ? 'github:mine:${repo.accountId}'
          : 'github:${repo.accountId}:${repo.repoId}';
  }
});

class TicketActionPending extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void start(String id) => state = {...state, id};

  void finish(String id) {
    final next = {...state}..remove(id);
    state = next;
  }
}

final ticketActionPendingProvider =
    NotifierProvider<TicketActionPending, Set<String>>(TicketActionPending.new);
