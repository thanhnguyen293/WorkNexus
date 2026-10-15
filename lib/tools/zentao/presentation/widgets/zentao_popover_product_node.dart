import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_popover_product_executions.dart';

/// Interactive tree node for a ZenTao Product in the bugs header switcher popover.
///
/// Clicking the folder selects the product (loading all bugs across all child executions).
/// Expanding the chevron reveals child executions; clicking a child execution
/// selects and filters bugs exclusively for that execution.
class ZenTaoPopoverProductNode extends ConsumerStatefulWidget {
  const ZenTaoPopoverProductNode({
    super.key,
    required this.targetAccountId,
    required this.product,
    required this.isFolderSelected,
    required this.currentExec,
    required this.openCount,
    required this.onSelectProduct,
    required this.onSelectExecution,
    this.initiallyExpanded = false,
  });

  final String targetAccountId;
  final ProviderProduct product;
  final bool isFolderSelected;
  final ZenTaoExecutionSelection? currentExec;
  final int openCount;
  final ValueChanged<ProviderProduct> onSelectProduct;
  final void Function(ProviderProduct product, ProviderExecution execution)
  onSelectExecution;
  final bool initiallyExpanded;

  @override
  ConsumerState<ZenTaoPopoverProductNode> createState() =>
      _ZenTaoPopoverProductNodeState();
}

class _ZenTaoPopoverProductNodeState
    extends ConsumerState<ZenTaoPopoverProductNode> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isCurrentFolder = widget.isFolderSelected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Product folder row
        InkWell(
          onTap: () => widget.onSelectProduct(widget.product),
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
                // Expand / Collapse Chevron
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(context.radii.xs),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Icon(
                      _expanded
                          ? LucideIcons.chevronDown300
                          : LucideIcons.chevronRight300,
                      size: 13,
                      color: c.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  LucideIcons.box300,
                  size: 14,
                  color: isCurrentFolder ? c.accent : c.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.product.name,
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
                if (widget.openCount > 0) ...[
                  Text(
                    '${widget.openCount}',
                    style: context.typography.monoXs.copyWith(
                      color: isCurrentFolder ? c.accent : c.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
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
        ),

        // Child executions when expanded
        if (_expanded)
          ZenTaoPopoverProductExecutions(
            accountId: widget.targetAccountId,
            product: widget.product,
            currentExec: widget.currentExec,
            onSelectExecution: (exec) =>
                widget.onSelectExecution(widget.product, exec),
          ),
      ],
    );
  }
}
