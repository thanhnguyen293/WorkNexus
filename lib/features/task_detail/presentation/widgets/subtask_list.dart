import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/semantic.dart';
import '../../../../core/util/labels.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/tinted_pill.dart';
import '../../../../l10n/app_localizations.dart';
import '../util/open_zentao_task.dart';
import 'detail_list_card.dart';
import 'section_label.dart';

/// A parent task's subtasks, as their own card: id, name, assignee and status;
/// tapping one opens it in the detail panel (fetched from ZenTao first when not
/// synced). Spaces itself from the region above.
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
    final l = AppL10n.of(context);
    setState(() => _opening = id);
    final res = await openZenTaoTask(ref, widget.ticket, id);
    if (!mounted) return;
    setState(() => _opening = null);
    if (res case Err(:final failure)) {
      showAppSnack(context, l.actionFailed(failure.message), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return DetailListCard(
      header: SectionLabel('${l.subtasks} (${widget.subtasks.length})'),
      rows: [
        for (final task in widget.subtasks)
          _Row(
            task: task,
            opening: _opening == task.id,
            onTap: _opening == null ? () => _open(task.id) : null,
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
    return DetailListRow(
      onTap: onTap,
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
              dimension: context.sizes.iconSm,
              child: const CircularProgressIndicator(),
            )
          else
            Icon(
              LucideIcons.chevronRight300,
              size: context.sizes.iconSm,
              color: c.textTertiary,
            ),
        ],
      ),
    );
  }
}
