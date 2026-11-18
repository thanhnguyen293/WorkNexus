import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';

/// One row of [SubtaskList]: id, name, assignee and status, indented [depth]
/// levels. With [showToggle], a leading slot holds the expand chevron when the
/// subtask has its own subtasks ([expanded] non-null), so rows at one depth
/// line up whether or not they have children.
class SubtaskRow extends StatelessWidget {
  const SubtaskRow({
    super.key,
    required this.task,
    required this.opening,
    this.onTap,
    this.depth = 0,
    this.showToggle = false,
    this.expanded,
    this.onToggle,
  });

  final TicketSubtask task;
  final bool opening;
  final VoidCallback? onTap;
  final int depth;
  final bool showToggle;
  final bool? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final sizes = context.sizes;
    final l = AppL10n.of(context);
    final expanded = this.expanded;
    // A level sits one chevron slot further in, so a child's chevron lines up
    // under its parent's id.
    final toggleSlot = sizes.iconSm + s.xxs * 2;
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
        child: Row(
          children: [
            if (showToggle) ...[
              SizedBox(width: depth * (toggleSlot + s.sm)),
              if (expanded != null)
                _Toggle(expanded: expanded, onTap: onToggle)
              else
                SizedBox(width: toggleSlot),
              SizedBox(width: s.sm),
            ],
            Text(
              '#${task.id}',
              style: context.typography.mono.copyWith(color: c.textSecondary),
            ),
            SizedBox(width: s.lg),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.bodySm.copyWith(
                  color: c.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (task.assignee case final assignee?) ...[
              SizedBox(width: s.lg),
              Text(
                assignee,
                style: context.typography.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
            SizedBox(width: s.lg),
            TintedPill(
              color: statusColor(c, task.status),
              label: statusLabel(l, task.status),
            ),
            SizedBox(width: s.sm),
            if (opening)
              SizedBox.square(
                dimension: sizes.iconSm,
                child: const CircularProgressIndicator(),
              )
            else
              Icon(
                LucideIcons.chevronRight300,
                size: sizes.iconSm,
                color: c.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows or hides a subtask's own subtasks; tapping it never opens the row.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.expanded, this.onTap});

  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Tooltip(
      message: expanded ? l.subtaskCollapse : l.subtaskExpand,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(context.spacing.xxs),
          child: Icon(
            expanded ? LucideIcons.chevronDown300 : LucideIcons.chevronRight300,
            size: context.sizes.iconSm,
            color: context.colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
