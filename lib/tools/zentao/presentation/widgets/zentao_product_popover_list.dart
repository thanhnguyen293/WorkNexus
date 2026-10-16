import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/board/domain/usecases/is_assigned_to_me.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_popover_product_node.dart';

/// Product list inside [ZenTaoProductPopover].
class ZenTaoProductPopoverList extends ConsumerWidget {
  const ZenTaoProductPopoverList({
    super.key,
    required this.account,
    required this.search,
    required this.tab,
    required this.onClose,
  });

  final Account account;
  final String search;
  final int tab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    final productsAsync = ref.watch(zentaoProductsProvider(account.id));
    final products = productsAsync.asData?.value ?? const <ProviderProduct>[];
    final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
    final selectedProduct = ref.watch(selectedZenTaoProductProvider);
    final currentExec = ref.watch(selectedZenTaoExecutionProvider);

    int openCount(String productId) => tickets
        .where(
          (t) =>
              t.accountId == account.id &&
              t.providerEntity is ZenTaoBugEntity &&
              (t.providerEntity as ZenTaoBugEntity).product == productId &&
              t.status != UnifiedStatus.done,
        )
        .length;

    // Yours: products with bugs assigned to you — not a "zone" guessed from
    // name prefixes, which ZenTao has no notion of.
    bool isMineProduct(ProviderProduct p) => tickets.any(
      (t) =>
          t.accountId == account.id &&
          t.providerEntity is ZenTaoBugEntity &&
          (t.providerEntity as ZenTaoBugEntity).product == p.id &&
          const IsAssignedToMe()(t, account),
    );

    final filtered = products.where((p) {
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!p.name.toLowerCase().contains(q)) return false;
      }
      final mine = isMineProduct(p);
      if (tab == 0 && !mine) return false;
      if (tab == 1 && mine) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final countA = openCount(a.id);
      final countB = openCount(b.id);
      if (countA != countB) return countB.compareTo(countA);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: c.border),

        // Filtered products list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No products found',
                    style: context.typography.bodySm.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final p = filtered[i];
                    final isSelected =
                        selectedProduct?.productId == p.id &&
                        currentExec == null;
                    final count = openCount(p.id);

                    return ZenTaoPopoverProductNode(
                      key: ValueKey('popover_prod_${p.id}'),
                      product: p,
                      isFolderSelected: isSelected,
                      openCount: count,
                      onSelectProduct: (product) {
                        ref
                            .read(appNavProvider.notifier)
                            .selectScope(product.id);
                        ref
                            .read(selectedZenTaoProductProvider.notifier)
                            .select(product);
                        ref
                            .read(selectedZenTaoExecutionProvider.notifier)
                            .clear();
                        ref
                            .read(filterStateProvider.notifier)
                            .openBoard(ref.read(boardKeyProvider));
                        onClose();
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
