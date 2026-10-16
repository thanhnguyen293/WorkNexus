import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/zentao_board_providers.dart';
import '../providers/zentao_table_providers.dart';
import 'zentao_product_popover.dart';

/// Top Viewport Header for ZenTao Bugs matching the task header style:
/// Interactive scope dropdown selector `[■] {productTitle} ▾`, caption (Bugs · [count]),
/// and primary + New bug button.
class ZentaoBugSectionHeader extends ConsumerStatefulWidget {
  const ZentaoBugSectionHeader({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<ZentaoBugSectionHeader> createState() =>
      _ZentaoBugSectionHeaderState();
}

class _ZentaoBugSectionHeaderState
    extends ConsumerState<ZentaoBugSectionHeader> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;

    // The selections are app-wide: they are this board's only while they
    // match this account and scope (as the board's own scoping requires).
    final pickedProduct = ref.watch(selectedZenTaoProductProvider);
    final selectedProduct =
        pickedProduct?.accountId == widget.account.id &&
            pickedProduct?.productId == widget.location.scopeId
        ? pickedProduct
        : null;
    final pickedExec = ref.watch(selectedZenTaoExecutionProvider);
    final selectedExec =
        selectedProduct != null && pickedExec?.accountId == widget.account.id
        ? pickedExec
        : null;
    final products = ref
        .watch(zentaoProductsProvider(widget.account.id))
        .asData
        ?.value;
    String? scopeTitle;
    if (selectedExec != null) {
      scopeTitle = selectedExec.executionName;
    } else if (selectedProduct != null) {
      scopeTitle = selectedProduct.productName;
    } else if (widget.location.scopeId != null && products != null) {
      for (final p in products) {
        if (p.id == widget.location.scopeId) {
          scopeTitle = p.name;
          break;
        }
      }
    }
    // Only until the section has picked a product.
    final displayTitle = scopeTitle ?? l.fieldProduct;
    final bugTable = ref.watch(zentaoBugTableProvider);
    final bugCount = bugTable.rows.length;

    return Container(
      color: c.surface,
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.xl, s.xs),
      child: Row(
        children: [
          MenuAnchor(
            controller: _menuController,
            alignmentOffset: const Offset(0, 6),
            menuChildren: [
              ZenTaoProductPopover(
                account: widget.account,
                onClose: _menuController.close,
              ),
            ],
            builder: (context, controller, child) {
              return InkWell(
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                borderRadius: BorderRadius.circular(context.radii.sm),
                hoverColor: c.surfaceSubtle,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: s.xs,
                    vertical: s.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(context.radii.xs),
                        ),
                      ),
                      SizedBox(width: s.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typography.titleLg.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: s.xs),
                      Icon(
                        controller.isOpen
                            ? LucideIcons.chevronUp300
                            : LucideIcons.chevronDown300,
                        size: 18,
                        color: c.textSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(width: s.md),
          Text(
            '${l.bugs} · $bugCount',
            style: context.typography.body.copyWith(color: c.textTertiary),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => ref
                .read(appNavProvider.notifier)
                .openEditor(
                  NewBugRoute(
                    accountId: widget.account.id,
                    productId: selectedProduct?.productId ?? '0',
                  ),
                ),
            icon: const Icon(LucideIcons.plus300, size: 16),
            label: Text(l.newBug),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.onAccent,
              padding: EdgeInsets.symmetric(horizontal: s.md, vertical: s.xs),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.radii.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
