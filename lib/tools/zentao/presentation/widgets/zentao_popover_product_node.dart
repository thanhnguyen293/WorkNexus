import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';

/// A ZenTao product in the bugs header switcher popover: a flat row that
/// selects the product. No executions under it — those belong to projects.
class ZenTaoPopoverProductNode extends StatelessWidget {
  const ZenTaoPopoverProductNode({
    super.key,
    required this.product,
    required this.isFolderSelected,
    required this.openCount,
    required this.onSelectProduct,
  });

  final ProviderProduct product;
  final bool isFolderSelected;
  final int openCount;
  final ValueChanged<ProviderProduct> onSelectProduct;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCurrentFolder = isFolderSelected;

    return InkWell(
      onTap: () => onSelectProduct(product),
      borderRadius: BorderRadius.circular(context.radii.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isCurrentFolder ? c.selectionFill : Colors.transparent,
          borderRadius: BorderRadius.circular(context.radii.xs),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.box300,
              size: 14,
              color: isCurrentFolder ? c.accent : c.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(
                  color: isCurrentFolder ? c.accent : c.textPrimary,
                  fontWeight: isCurrentFolder
                      ? FontWeight.w600
                      : FontWeight.w400,
                  fontSize: 12,
                ),
              ),
            ),
            if (openCount > 0) ...[
              Text(
                '$openCount',
                style: context.typography.monoXs.copyWith(
                  color: isCurrentFolder ? c.accent : c.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isCurrentFolder
                    ? c.accent.withValues(alpha: 0.15)
                    : c.surfaceSubtle,
                borderRadius: BorderRadius.circular(context.radii.xs),
              ),
              child: Text(
                'Product',
                style: context.typography.monoXs.copyWith(
                  color: isCurrentFolder ? c.accent : c.textTertiary,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
