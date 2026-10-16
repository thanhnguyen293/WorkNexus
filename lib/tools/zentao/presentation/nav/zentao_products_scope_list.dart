import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/scope_filter_field.dart';
import '../../../../shared/shell_pane/scope_list_body.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/entities/zentao_product_group.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_product_set_node.dart';
import 'zentao_product_tree_node.dart';

/// Scope list for ZenTao Bugs: quick scopes + pinned / recent / all products.
class ZentaoProductsScopeList extends ConsumerStatefulWidget {
  const ZentaoProductsScopeList({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<ZentaoProductsScopeList> createState() =>
      _ZentaoProductsScopeListState();
}

class _ZentaoProductsScopeListState
    extends ConsumerState<ZentaoProductsScopeList> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final productsAsync = ref.watch(zentaoProductsProvider(widget.account.id));
    final tickets = ref.watch(ticketsProvider).asData?.value ?? const [];
    final pinned = ref.watch(
      appSettingsProvider.select((s) => s.pinnedProjects),
    );

    return productsAsync.when(
      data: (products) {
        final query = _filter.trim().toLowerCase();
        final filtered = query.isEmpty
            ? products
            : products
                  .where((p) => p.name.toLowerCase().contains(query))
                  .toList();

        int openCount(String productId) => tickets
            .where(
              (t) =>
                  t.accountId == widget.account.id &&
                  (t.providerEntity is ZenTaoBugEntity &&
                      (t.providerEntity as ZenTaoBugEntity).product ==
                          productId) &&
                  t.status != UnifiedStatus.done,
            )
            .length;

        String keyOf(ProviderProduct p) => '${p.accountId}:${p.id}';

        final pinnedProducts = filtered
            .where((p) => pinned.contains(keyOf(p)))
            .toList();
        final unpinnedProducts = filtered
            .where((p) => !pinned.contains(keyOf(p)))
            .toList();

        final recentIds = widget.location.recentScopeIds.toSet();
        final recentProducts = unpinnedProducts
            .where((p) => recentIds.contains(p.id))
            .toList();

        // ZenTao's own program › line grouping (or one flat list when the
        // server gives none).
        final tree = ZenTaoProductTree.of(unpinnedProducts);

        void selectProduct(ProviderProduct p) {
          ref.read(appNavProvider.notifier).selectScope(p.id);
          ref.read(selectedZenTaoProductProvider.notifier).select(p);
          // An execution picked under another product would narrow this
          // product's bugs to nothing.
          ref.read(selectedZenTaoExecutionProvider.notifier).clear();
          ref
              .read(filterStateProvider.notifier)
              .openBoard(ref.read(boardKeyProvider));
        }

        final currentSelectedProduct = ref.watch(selectedZenTaoProductProvider);

        return Column(
          children: [
            ScopeFilterField(
              placeholder: l.filterProducts,
              onChanged: (val) => setState(() => _filter = val),
            ),
            Expanded(
              child: ScopeListBody(
                // No quick rows: ZenTao lists bugs per product only, and the
                // board's own "Assigned to me" chip narrows to your bugs.
                groupTitle: l.zentaoProductsGroup,
                pinnedRows: [
                  for (final p in pinnedProducts)
                    ZentaoProductTreeNode(
                      key: ValueKey('pinned_prod_${p.id}'),
                      account: widget.account,
                      product: p,
                      location: widget.location,
                      openCount: openCount(p.id),
                      isPinned: true,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                    ),
                ],
                recentRows: [
                  for (final p in recentProducts)
                    ScopeRow(
                      name: p.name,
                      count: openCount(p.id),
                      selected:
                          widget.location.scopeId == p.id ||
                          currentSelectedProduct?.productId == p.id,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                      onTap: () => selectProduct(p),
                    ),
                ],
                allRows: [
                  for (final group in tree.groups)
                    ZentaoProductSetNode(
                      key: ValueKey('zentao_prod_group_${group.id}'),
                      account: widget.account,
                      group: group,
                      location: widget.location,
                      openCountOf: openCount,
                      onSelectProduct: selectProduct,
                    ),
                  // In no program or line: after the folders, as ZenTao
                  // lists them.
                  for (final p in tree.ungrouped)
                    ZentaoProductTreeNode(
                      key: ValueKey('zentao_prod_${p.id}'),
                      account: widget.account,
                      product: p,
                      location: widget.location,
                      openCount: openCount(p.id),
                      isPinned: false,
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SidebarStatusRow(label: l.loadingProjects, loading: true),
      ),
      error: (_, _) => Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: SidebarStatusRow(
          label: l.projectsUnavailable,
          isError: true,
          onRetry: () =>
              ref.invalidate(zentaoProductsProvider(widget.account.id)),
        ),
      ),
    );
  }
}
