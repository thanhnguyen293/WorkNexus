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
import 'zentao_execution_popover.dart';

/// Top Viewport Header for ZenTao Tasks (specs.md §5.1):
/// Interactive scope dropdown selector `[■] {scopeTitle} ▾`, caption (Tasks · [count]),
/// and primary + New task button.
class ZentaoTaskSectionHeader extends ConsumerStatefulWidget {
  const ZentaoTaskSectionHeader({
    super.key,
    required this.account,
    required this.location,
  });

  final Account account;
  final ToolLocation location;

  @override
  ConsumerState<ZentaoTaskSectionHeader> createState() =>
      _ZentaoTaskSectionHeaderState();
}

class _ZentaoTaskSectionHeaderState
    extends ConsumerState<ZentaoTaskSectionHeader> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final s = context.spacing;

    // The selection is app-wide: it is this board's only while it matches
    // this account and scope (as the board's own scoping requires).
    final picked = ref.watch(selectedZenTaoExecutionProvider);
    final execution =
        picked?.accountId == widget.account.id &&
            picked?.executionId == widget.location.scopeId
        ? picked
        : null;
    final projects = ref
        .watch(zentaoProjectsProvider(widget.account.id))
        .asData
        ?.value;
    String? scopeTitle;
    if (execution != null) {
      scopeTitle = execution.executionName;
    } else if (widget.location.scopeId != null && projects != null) {
      for (final p in projects) {
        if (p.id == widget.location.scopeId) {
          scopeTitle = p.name;
          break;
        }
      }
    }
    // Only until the section has picked a place.
    final displayTitle = scopeTitle ?? l.zentaoProjectsGroup;
    final taskTable = ref.watch(zentaoTaskTableProvider);
    final taskCount = taskTable.rows.length;

    return Container(
      color: c.surface,
      padding: EdgeInsets.fromLTRB(s.xl, s.md, s.xl, s.xs),
      child: Row(
        children: [
          MenuAnchor(
            controller: _menuController,
            alignmentOffset: const Offset(0, 6),
            menuChildren: [
              ZenTaoExecutionPopover(
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
            '${l.tasks} · $taskCount',
            style: context.typography.body.copyWith(color: c.textTertiary),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => ref
                .read(appNavProvider.notifier)
                .openEditor(
                  NewTaskRoute(
                    accountId: widget.account.id,
                    // Filed into the open execution, not ZenTao's current one.
                    executionId: execution?.executionId ?? '0',
                  ),
                ),
            icon: const Icon(LucideIcons.plus300, size: 16),
            label: Text(l.newTask),
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
