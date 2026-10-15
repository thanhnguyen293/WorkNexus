import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../../domain/entities/zentao_product_group.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_product_tree_node.dart';

/// Level 1 node in the ZenTao Bugs navigation tree: represents a Product Group/Department (e.g. `VN`, `HK`).
class ZentaoProductSetNode extends ConsumerWidget {
  const ZentaoProductSetNode({
    super.key,
    required this.account,
    required this.group,
    required this.tickets,
    required this.location,
    required this.openCountOf,
    required this.onSelectProduct,
  });

  final Account account;
  final ZenTaoProductGroup group;
  final List<Ticket> tickets;
  final ToolLocation location;
  final int Function(String productId) openCountOf;
  final ValueChanged<ProviderProduct> onSelectProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final groupKey = '${account.id}:${group.id}';

    final isCollapsed = ref.watch(
      zentaoProductSetsCollapsedProvider.select(
        (set) => set.contains(groupKey),
      ),
    );

    final totalCount = group.products.fold<int>(
      0,
      (sum, p) => sum + openCountOf(p.id),
    );

    final pinned = ref.watch(
      appSettingsProvider.select((st) => st.pinnedProjects),
    );

    String keyOf(ProviderProduct p) => '${p.accountId}:${p.id}';

    return Padding(
      padding: EdgeInsets.only(bottom: s.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            onTap: () => ref
                .read(zentaoProductSetsCollapsedProvider.notifier)
                .toggle(groupKey),
            borderRadius: BorderRadius.circular(context.radii.sm),
            child: Container(
              height: context.sizes.controlSm,
              padding: EdgeInsets.symmetric(horizontal: s.xs),
              child: Row(
                children: [
                  Icon(
                    isCollapsed
                        ? LucideIcons.chevronRight300
                        : LucideIcons.chevronDown300,
                    size: context.sizes.iconXs,
                    color: c.textTertiary,
                  ),
                  SizedBox(width: s.xs),
                  Icon(
                    LucideIcons.folderKanban300,
                    size: context.sizes.iconSm,
                    color: c.accent,
                  ),
                  SizedBox(width: s.xs),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.mono.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  if (totalCount > 0) ...[
                    SidebarCountBadge(totalCount),
                    SizedBox(width: s.xs),
                  ],
                ],
              ),
            ),
          ),
          if (!isCollapsed)
            SidebarTreeBranch(
              strong: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final p in group.products)
                    ZentaoProductTreeNode(
                      key: ValueKey('zentao_prod_${p.id}'),
                      account: account,
                      product: p,
                      tickets: tickets,
                      location: location,
                      openCount: openCountOf(p.id),
                      isPinned: pinned.contains(keyOf(p)),
                      onPinToggle: () => ref
                          .read(appSettingsProvider.notifier)
                          .togglePinnedProject(keyOf(p)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
