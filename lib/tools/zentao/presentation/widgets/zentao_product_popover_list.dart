import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_filter_providers.dart';
import 'zentao_popover_product_node.dart';

/// Product list inside [ZenTaoProductPopover].
class ZenTaoProductPopoverList extends ConsumerWidget {
  const ZenTaoProductPopoverList({
    super.key,
    required this.account,
    required this.search,
    required this.tab,
    required this.activeZone,
    required this.onClose,
  });

  final Account account;
  final String search;
  final int tab;
  final String? activeZone;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);

    final productsAsync = ref.watch(zentaoProductsProvider(account.id));
    final products = productsAsync.asData?.value ?? const <ProviderProduct>[];
    final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
    final selectedProduct = ref.watch(selectedZenTaoProductProvider);
    final currentExec = ref.watch(selectedZenTaoExecutionProvider);
    final userZone = ref.watch(userZoneProvider);

    int openCount(String productId) => tickets
        .where(
          (t) =>
              t.accountId == account.id &&
              t.providerEntity is ZenTaoBugEntity &&
              (t.providerEntity as ZenTaoBugEntity).product == productId &&
              t.status != UnifiedStatus.done,
        )
        .length;

    bool matchesDept(ProviderProduct p, String dept) {
      if (dept.isEmpty) return false;
      final d = dept.toUpperCase();
      final name = p.name.toUpperCase();
      return name.startsWith('${d}_') ||
          name.startsWith('$d-') ||
          name.startsWith('$d ') ||
          name.contains('_${d}_') ||
          name.contains('[$d]') ||
          name.startsWith(d);
    }

    final filtered = products.where((p) {
      if (search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!p.name.toLowerCase().contains(q)) return false;
      }
      if (activeZone != null && !matchesDept(p, activeZone!)) {
        return false;
      }
      final isMineProduct = matchesDept(p, userZone);
      if (tab == 0 && !isMineProduct) return false;
      if (tab == 1 && isMineProduct) return false;
      return true;
    }).toList();

    filtered.sort((a, b) {
      final aDept = matchesDept(a, userZone);
      final bDept = matchesDept(b, userZone);
      if (aDept != bDept) return aDept ? -1 : 1;
      final countA = openCount(a.id);
      final countB = openCount(b.id);
      if (countA != countB) return countB.compareTo(countA);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Column(
      children: [
        // "All products" option at top
        InkWell(
          onTap: () {
            ref.read(appNavProvider.notifier).selectScope(null);
            ref.read(selectedZenTaoProductProvider.notifier).clear();
            ref.read(selectedZenTaoExecutionProvider.notifier).clear();
            ref
                .read(filterStateProvider.notifier)
                .openBoard(ref.read(boardKeyProvider));
            onClose();
          },
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(
                  selectedProduct == null
                      ? LucideIcons.check300
                      : LucideIcons.layers300,
                  size: 14,
                  color: selectedProduct == null ? c.accent : c.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  l.allProducts,
                  style: context.typography.bodySm.copyWith(
                    fontWeight: selectedProduct == null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selectedProduct == null ? c.accent : c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                      targetAccountId: account.id,
                      product: p,
                      isFolderSelected: isSelected,
                      currentExec: currentExec,
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
                      onSelectExecution: (product, exec) {
                        ref
                            .read(appNavProvider.notifier)
                            .selectScope(product.id);
                        ref
                            .read(selectedZenTaoProductProvider.notifier)
                            .select(product);
                        ref
                            .read(selectedZenTaoExecutionProvider.notifier)
                            .select(exec);
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
