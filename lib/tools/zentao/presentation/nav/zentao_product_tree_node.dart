import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/pinned_execution.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/board/presentation/providers/board_providers.dart';
import '../../../../shared/shell_pane/sidebar_primitives.dart';
import '../providers/zentao_board_providers.dart';
import 'zentao_product_executions.dart';

/// Level 2 node in the ZenTao Bugs navigation tree: represents a single Product.
/// Can be expanded to show child Executions (sprints), and tapped to filter bugs by product.
class ZentaoProductTreeNode extends ConsumerStatefulWidget {
  const ZentaoProductTreeNode({
    super.key,
    required this.account,
    required this.product,
    required this.tickets,
    required this.location,
    required this.openCount,
    required this.isPinned,
    required this.onPinToggle,
  });

  final Account account;
  final ProviderProduct product;
  final List<Ticket> tickets;
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

  void _togglePin(String pinKey) async {
    if (widget.isPinned) {
      ref.read(appSettingsProvider.notifier).togglePinnedProject(pinKey);
    } else {
      final projects =
          ref.read(zentaoProjectsProvider(widget.account.id)).asData?.value ??
          const <ProviderProject>[];
      final matched = projects.firstWhereOrNull(
        (proj) =>
            proj.name.trim().toLowerCase() ==
                widget.product.name.trim().toLowerCase() ||
            proj.id == widget.product.id,
      );
      final projectId = matched?.id ?? widget.product.id;
      var childExecs = ref
          .read(
            zentaoExecutionsProvider((
              accountId: widget.account.id,
              projectId: projectId,
            )),
          )
          .asData
          ?.value;
      if (childExecs == null) {
        try {
          childExecs = await ref.read(
            zentaoExecutionsProvider((
              accountId: widget.account.id,
              projectId: projectId,
            )).future,
          );
        } catch (_) {}
      }
      ref
          .read(appSettingsProvider.notifier)
          .togglePinnedProject(
            pinKey,
            childExecutions: childExecs
                ?.map(
                  (e) => PinnedExecution(
                    accountId: e.accountId,
                    projectId: projectId,
                    executionId: e.id,
                    name: e.name,
                  ),
                )
                .toList(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final key = 'prod:${widget.account.id}:${widget.product.id}';

    final expanded = ref.watch(
      zentaoExecutionProjectsExpandedProvider.select(
        (set) => set.contains(key),
      ),
    );

    final selected =
        (widget.location.scopeId == widget.product.id ||
            ref.watch(selectedZenTaoProductProvider)?.productId ==
                widget.product.id) &&
        ref.watch(selectedZenTaoExecutionProvider) == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
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
                  InkWell(
                    onTap: () => ref
                        .read(zentaoExecutionProjectsExpandedProvider.notifier)
                        .toggle(key),
                    borderRadius: BorderRadius.circular(context.radii.xs),
                    child: Padding(
                      padding: EdgeInsets.all(s.xxs),
                      child: Icon(
                        expanded
                            ? LucideIcons.chevronDown300
                            : LucideIcons.chevronRight300,
                        size: context.sizes.iconXs,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                  SizedBox(width: s.xxs),
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
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
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
                      onTap: () => _togglePin(
                        '${widget.account.id}:${widget.product.id}',
                      ),
                      tooltip: widget.isPinned ? l.unpinProject : l.pinProject,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          SidebarTreeBranch(
            child: ZentaoProductExecutions(
              account: widget.account,
              product: widget.product,
              tickets: widget.tickets,
            ),
          ),
      ],
    );
  }
}
