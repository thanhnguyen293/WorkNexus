import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../shared/board/domain/entities/filter_state.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/usecases/build_zentao_module_tree.dart';
import '../../domain/usecases/build_zentao_task_board.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import 'task_module_names_provider.dart';
import 'zentao_board_providers.dart';

/// Whether the bug board's module tree hides modules with no bugs. Kept for
/// the session, so it survives switching products and sections.
class ZenTaoHideEmptyModules extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final zentaoHideEmptyModulesProvider =
    NotifierProvider<ZenTaoHideEmptyModules, bool>(ZenTaoHideEmptyModules.new);

/// The module tree of the board on screen (the bug board's product when
/// [bugs], else the task board's execution) for the side panel, counted from
/// the tickets the board would show with every filter but the module one.
/// Loading or failed while the module names are.
final zentaoModuleTreeProvider = Provider.autoDispose
    .family<AsyncValue<ZenTaoModuleTree>, bool>((ref, bugs) {
      final query = ref.watch(boardQueryProvider);
      final picked = query.filter.modules;
      final hideEmpty = ref.watch(zentaoHideEmptyModulesProvider);
      final unpicked = query.withFilter(query.filter.copyWith(modules: {}));
      // Counted as the board shows them: its columns, so a view without
      // Closed does not count closed bugs.
      final List<Ticket> shown = bugs
          ? [
              for (final c in BuildZenTaoBugBoard(
                includeClosed:
                    ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all,
              )(unpicked).columns)
                ...c.tickets,
            ]
          : [
              for (final c in BuildZenTaoTaskBoard(
                dueThisWeekOnly: ref.watch(zentaoTaskDueThisWeekProvider),
              )(unpicked).columns)
                ...c.tickets,
            ];
      return ref
          .watch(zentaoBoardModuleNamesProvider(bugs))
          .whenData(
            (paths) => const BuildZenTaoModuleTree()(
              ZenTaoModuleTreeInput(
                paths: paths,
                tickets: shown,
                hideEmpty: hideEmpty,
                selected: picked.length == 1 ? picked.first : null,
              ),
            ),
          );
    });

/// How many bugs the board shows and how many it would with no chip filters
/// (its view kept): the header's "6 of 21 shown".
final zentaoBugShownCountProvider =
    Provider.autoDispose<({int shown, int total})>((ref) {
      final query = ref.watch(boardQueryProvider);
      final build = BuildZenTaoBugBoard(
        includeClosed:
            ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all,
      );
      int count(ZenTaoBugBoardModel board) =>
          board.columns.fold(0, (n, c) => n + c.tickets.length);
      final unfiltered = query.withFilter(
        FilterState(
          workspaceId: query.filter.workspaceId,
          savedView: query.filter.savedView,
        ),
      );
      return (
        shown: count(ref.watch(zentaoBugBoardProvider)),
        total: count(build(unfiltered)),
      );
    });
