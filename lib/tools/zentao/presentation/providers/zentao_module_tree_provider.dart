import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/board/domain/entities/filter_state.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../domain/usecases/build_zentao_bug_board.dart';
import '../../domain/usecases/build_zentao_module_tree.dart';
import '../../domain/value_objects/zentao_bug_browse_type.dart';
import 'bug_module_names_provider.dart';
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

/// The open product's module tree for the side panel, counted from the bugs
/// the board would show with every filter but the module one. Loading or
/// failed while the product's module names are.
final zentaoModuleTreeProvider =
    Provider.autoDispose<AsyncValue<ZenTaoModuleTree>>((ref) {
      final product = ref.watch(selectedZenTaoProductProvider);
      if (product == null) return const AsyncData(ZenTaoModuleTree.empty);
      final query = ref.watch(boardQueryProvider);
      final picked = query.filter.modules;
      final hideEmpty = ref.watch(zentaoHideEmptyModulesProvider);
      // Counted as the board shows them: its columns, so a view without
      // Closed does not count closed bugs.
      final shown = BuildZenTaoBugBoard(
        includeClosed:
            ref.watch(zentaoBugTabProvider) == ZenTaoBugBrowseType.all,
      )(query.withFilter(query.filter.copyWith(modules: {})));
      return ref
          .watch(bugModuleNamesProvider((product.accountId, product.productId)))
          .whenData(
            (paths) => const BuildZenTaoModuleTree()(
              ZenTaoModuleTreeInput(
                paths: paths,
                bugs: [for (final c in shown.columns) ...c.tickets],
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
