import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'zentao_board_providers.dart';

/// Which ZenTao board a scope title is asked for: [bugs] or tasks, of
/// [accountId], at the location's [scopeId].
typedef ZenTaoScopeTitleKey = ({String accountId, String? scopeId, bool bugs});

/// The name of what a ZenTao board is scoped to — the picked execution, else
/// the product (bugs), as its header shows it — or null until one is picked.
///
/// The selections are app-wide: they are this board's only while they match
/// its account and scope (as the board's own scoping requires).
final zentaoScopeTitleProvider = Provider.family<String?, ZenTaoScopeTitleKey>((
  ref,
  key,
) {
  final pickedExec = ref.watch(selectedZenTaoExecutionProvider);
  final exec = pickedExec?.accountId == key.accountId ? pickedExec : null;
  if (!key.bugs) {
    return exec?.executionId == key.scopeId ? exec?.executionName : null;
  }

  final pickedProduct = ref.watch(selectedZenTaoProductProvider);
  final product =
      pickedProduct?.accountId == key.accountId &&
          pickedProduct?.productId == key.scopeId
      ? pickedProduct
      : null;
  if (product != null) return exec?.executionName ?? product.productName;
  if (key.scopeId == null) return null;
  final products = ref
      .watch(zentaoProductsProvider(key.accountId))
      .asData
      ?.value;
  return products?.where((p) => p.id == key.scopeId).firstOrNull?.name;
});
