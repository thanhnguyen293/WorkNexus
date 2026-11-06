import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';

/// Opens [product]'s bug board: its scope, its selection and its own filter.
/// An execution picked under another product would narrow this product's
/// bugs to nothing, so it is cleared.
void selectBugBoardProduct(WidgetRef ref, ProviderProduct product) {
  ref.read(appNavProvider.notifier).selectScope(product.id);
  ref.read(selectedZenTaoProductProvider.notifier).select(product);
  ref.read(selectedZenTaoExecutionProvider.notifier).clear();
  ref.read(filterStateProvider.notifier).openBoard(ref.read(boardKeyProvider));
}
