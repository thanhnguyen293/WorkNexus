import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../providers/zentao_board_providers.dart';

/// A product in the ZenTao Bugs navigation tree: a flat row — tapping it opens
/// the product's bug board — with a pin toggle. No executions under it: those
/// belong to projects (the Executions tab), not to products.
class ZentaoProductTreeNode extends ConsumerStatefulWidget {
  const ZentaoProductTreeNode({
    super.key,
    required this.account,
    required this.product,
    required this.location,
    required this.openCount,
    required this.isPinned,
    required this.onPinToggle,
  });

  final Account account;
  final ProviderProduct product;
  final ToolLocation location;
  final int openCount;
  final bool isPinned;
  final VoidCallback onPinToggle;

  @override
  ConsumerState<ZentaoProductTreeNode> createState() =>
      _ZentaoProductTreeNodeState();
}

class _ZentaoProductTreeNodeState extends ConsumerState<ZentaoProductTreeNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final selected =
        (widget.location.scopeId == widget.product.id ||
            ref.watch(selectedZenTaoProductProvider)?.productId ==
                widget.product.id) &&
        ref.watch(selectedZenTaoExecutionProvider) == null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: () {
          ref.read(appNavProvider.notifier).selectScope(widget.product.id);
          ref
              .read(selectedZenTaoProductProvider.notifier)
              .select(widget.product);
          ref.read(selectedZenTaoExecutionProvider.notifier).clear();
          ref
              .read(filterStateProvider.notifier)
              .openBoard(ref.read(boardKeyProvider));
        },
        borderRadius: BorderRadius.circular(context.radii.sm),
        child: Container(
          height: context.sizes.controlSm,
          padding: EdgeInsets.symmetric(horizontal: s.xs),
          decoration: BoxDecoration(
            color: selected ? c.selectionFill : Colors.transparent,
            borderRadius: BorderRadius.circular(context.radii.sm),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.box300,
                size: context.sizes.iconSm,
                color: selected ? c.accent : c.textSecondary,
              ),
              SizedBox(width: s.xs),
              Expanded(
                child: Text(
                  widget.product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.bodySm.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? c.textPrimary : c.textSecondary,
                  ),
                ),
              ),
              if (widget.openCount > 0) ...[
                SidebarCountBadge(widget.openCount),
                SizedBox(width: s.xs),
              ],
              if (widget.isPinned || _hovered)
                SidebarPinButton(
                  pinned: widget.isPinned,
                  onTap: widget.onPinToggle,
                  tooltip: widget.isPinned ? l.unpinProject : l.pinProject,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
