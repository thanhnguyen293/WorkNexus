import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/util/synthetic_labels.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/scope_filter_field.dart';
import '../../../../shared/shell_pane/scope_list_body.dart';
import '../../../../shared/shell_pane/scope_rows.dart';
import '../../../../shared/shell_pane/sidebar_tree_rows.dart';
import '../../domain/entities/zentao_product_group.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_filter_providers.dart';
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

        final projects = ref
                .watch(zentaoProjectsProvider(widget.account.id))
                .asData
                ?.value ??
            const <ProviderProject>[];

        String matchedProjectId(ProviderProduct prod) {
          final matched = projects.firstWhereOrNull(
            (proj) =>
                proj.name.trim().toLowerCase() ==
                    prod.name.trim().toLowerCase() ||
                proj.id == prod.id,
          );
          return matched?.id ?? prod.id;
        }

        int openCount(String productId) => tickets
            .where(
              (t) =>
                  t.accountId == widget.account.id &&
                  t.status != UnifiedStatus.done &&
                  ((t.providerEntity is ZenTaoBugEntity &&
                          (t.providerEntity as ZenTaoBugEntity).product ==
                              productId) ||
                      t.labels.contains(zentaoProductLabel(productId))),
            )
            .length;

        String keyOf(ProviderProduct p) => '${p.accountId}:${p.id}';

        final pinnedExecutions = ref
            .watch(appSettingsProvider.select((s) => s.pinnedExecutions))
            .where((e) => e.accountId == widget.account.id)
            .toList();

        final pinnedProducts = filtered.where((p) {
          final isProdPinned = pinned.contains(keyOf(p));
          final mId = matchedProjectId(p);
          final hasPinnedChild = pinnedExecutions
              .any((e) => e.projectId == p.id || e.projectId == mId);
          return isProdPinned || hasPinnedChild;
        }).toList();

        final unpinnedProducts = filtered
            .where((p) => !pinned.contains(keyOf(p)))
            .toList();

        final recentIds = widget.location.recentScopeIds.toSet();
        final recentProducts = unpinnedProducts
            .where((p) => recentIds.contains(p.id))
            .toList();

        final userZone = ref.watch(userZoneProvider);
        final groups = ZenTaoProductGroup.group(
          unpinnedProducts,
          prioritizeZone: userZone,
        );

        void selectProduct(ProviderProduct p) {
          ref.read(appNavProvider.notifier).selectScope(p.id);
          ref.read(selectedZenTaoProductProvider.notifier).select(p);
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
                groupTitle: l.allProducts,
                quickScopeRows: [
                  ScopeQuickRow(
                    label: l.allProducts,
                    icon: LucideIcons.layers300,
                    selected:
                        widget.location.scopeId == null &&
                        widget.location.quickScope == QuickScope.all &&
                        currentSelectedProduct == null,
                    onTap: () {
                      ref.read(appNavProvider.notifier).selectScope(null);
                      ref
                          .read(appNavProvider.notifier)
                          .setQuickScope(QuickScope.all);
                      ref.read(selectedZenTaoProductProvider.notifier).clear();
                    },
                  ),
                  ScopeQuickRow(
                    label: l.assignedToMe,
                    icon: LucideIcons.user300,
                    selected:
                        widget.location.quickScope == QuickScope.assignedToMe,
                    onTap: () {
                      ref
                          .read(appNavProvider.notifier)
                          .setQuickScope(QuickScope.assignedToMe);
                    },
                  ),
                ],
                pinnedRows: [
                  for (final p in pinnedProducts)
                    ZentaoProductTreeNode(
                      key: ValueKey('pinned_prod_${p.id}'),
                      account: widget.account,
                      product: p,
                      tickets: tickets,
                      location: widget.location,
                      openCount: openCount(p.id),
                      isPinned: pinned.contains(keyOf(p)),
                      isInPinned: true,
                      onlyPinnedExecutions: !pinned.contains(keyOf(p)),
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
                  for (final group in groups)
                    ZentaoProductSetNode(
                      key: ValueKey('zentao_prod_group_${group.id}'),
                      account: widget.account,
                      group: group,
                      tickets: tickets,
                      location: widget.location,
                      openCountOf: openCount,
                      onSelectProduct: selectProduct,
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
