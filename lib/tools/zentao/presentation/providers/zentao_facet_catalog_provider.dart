import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/board/domain/usecases/derive_board_facets.dart';
import '../../domain/usecases/build_zentao_facet_catalog.dart';
import 'bug_module_names_provider.dart';
import 'zentao_board_providers.dart';
import 'zentao_data_providers.dart';

/// Every choice the bug board ([bugs]) or task board can be filtered by: the
/// fixed ones at once, the people of its product or execution once they load.
final zentaoFacetCatalogProvider = Provider.autoDispose
    .family<BoardFacetCatalog, bool>(
      (ref, bugs) => const BuildZenTaoFacetCatalog()(
        ZenTaoFacetCatalogInput(
          bugs: bugs,
          members: ref.watch(_boardMembersProvider(bugs)).value ?? const [],
          modules: bugs ? ref.watch(_productModulesProvider) : const {},
        ),
      ),
    );

/// The bug board product's modules (id → path), for the module filter. Only
/// bugs carry a module here, so the task board has none. Until they load, or
/// when they cannot, the board has no module filter (its other filters work).
final _productModulesProvider = Provider.autoDispose<Map<String, String>>((
  ref,
) {
  final product = ref.watch(selectedZenTaoProductProvider);
  if (product == null) return const {};
  return ref
          .watch(bugModuleNamesProvider((product.accountId, product.productId)))
          .value ??
      const {};
});

final _boardMembersProvider = FutureProvider.autoDispose
    .family<List<ProviderUser>, bool>((ref, bugs) async {
      final team = ref.read(zentaoTeamMembersProvider);
      final Result<List<ProviderUser>> members;
      if (bugs) {
        final product = ref.watch(selectedZenTaoProductProvider);
        if (product == null) return const [];
        members = await team.productMembers(
          product.accountId,
          product.productId,
        );
      } else {
        final execution = ref.watch(selectedZenTaoExecutionProvider);
        if (execution == null) return const [];
        members = await team.executionMembers(
          execution.accountId,
          execution.executionId,
        );
      }
      if (members case Err(:final failure)) {
        appTalker.warning('ZenTao board members: ${failure.message}');
      }
      return members.valueOrNull ?? const [];
    });
