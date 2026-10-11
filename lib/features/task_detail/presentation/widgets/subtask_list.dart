import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/open_zentao_task.dart';
import 'section_label.dart';

/// A parent task's subtasks: id, name, assignee and status; tapping one opens
/// it in the detail panel (fetched from ZenTao first when not synced).
class SubtaskList extends ConsumerStatefulWidget {
  const SubtaskList({super.key, required this.ticket, required this.subtasks});

  /// The parent task.
  final Ticket ticket;
  final List<TicketSubtask> subtasks;

  @override
  ConsumerState<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends ConsumerState<SubtaskList> {
  /// The subtask being fetched to open, if any.
  String? _opening;

  Future<void> _open(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppL10n.of(context);
    setState(() => _opening = id);
    final res = await openZenTaoTask(ref, widget.ticket, id);
    if (!mounted) return;
    setState(() => _opening = null);
    if (res case Err(:final failure)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.actionFailed(failure.message))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel('${l.subtasks} (${widget.subtasks.length})'),
        SizedBox(height: context.spacing.md),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              for (final (i, task) in widget.subtasks.indexed) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                _Row(
                  task: task,
                  opening: _opening == task.id,
                  onTap: _opening == null ? () => _open(task.id) : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.task, required this.opening, this.onTap});

  final TicketSubtask task;
  final bool opening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    return InkWell(
      mouseCursor: WidgetStateMouseCursor.clickable,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: s.lg, vertical: s.md),
        child: Row(
          children: [
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
                dimension: s.lg,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: c.accent,
                ),
              )
            else
              Icon(
                LucideIcons.chevronRight300,
                size: s.lg,
                color: c.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
