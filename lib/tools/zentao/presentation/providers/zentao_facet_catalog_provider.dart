import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/debug/app_talker.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/board/domain/usecases/derive_board_facets.dart';
import '../../domain/usecases/build_zentao_facet_catalog.dart';
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
        ),
      ),
    );

/// The selected product's members (bug board) or execution's team (task
/// board). A failure leaves the people to what the tickets carry, as before
/// the catalog: the filter still works, with fewer names.
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
