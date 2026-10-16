import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';

/// Keeps the Bugs board on a product of [account]: ZenTao lists bugs per
/// product only, so there is no board without one. The scope's product when
/// it has one; otherwise — first open, the product gone, another account — a
/// pinned product, else the first. Only while the section is on screen (the
/// viewport keeps a few alive).
void keepBugBoardProduct(
  BuildContext context,
  WidgetRef ref,
  Account account,
  ToolLocation location,
) {
  final products = ref.watch(zentaoProductsProvider(account.id)).asData?.value;
  if (products == null ||
      products.isEmpty ||
      !TickerMode.valuesOf(context).enabled) {
    return;
  }
  final scoped = products.where((p) => p.id == location.scopeId).firstOrNull;
  final pinned = ref.read(appSettingsProvider).pinnedProjects;
  final ProviderProduct pick =
      scoped ??
      products.firstWhere(
        (p) => pinned.contains('${account.id}:${p.id}'),
        orElse: () => products.first,
      );
  // Product ids are per server: another account's product 1 is not this one.
  final selected = ref.read(selectedZenTaoProductProvider);
  final current =
      selected?.accountId == account.id && selected?.productId == pick.id;
  if (scoped != null && current) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (scoped == null) {
      ref.read(appNavProvider.notifier).selectScope(pick.id);
      ref.read(selectedZenTaoExecutionProvider.notifier).clear();
    }
    ref.read(selectedZenTaoProductProvider.notifier).select(pick);
    ref
        .read(filterStateProvider.notifier)
        .openBoard(ref.read(boardKeyProvider));
  });
}
