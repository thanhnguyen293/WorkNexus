import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_board_status.dart';
import '../../../../core/domain/value_objects/zentao_task_column.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// Sprint chip showing execution name.
class ZenTaoSprintTag extends StatelessWidget {
  const ZenTaoSprintTag({super.key, required this.sprint});

  final String? sprint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = (sprint != null && sprint!.trim().isNotEmpty)
        ? sprint!.trim()
        : '—';
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.bodySm.copyWith(color: c.textSecondary),
    );
  }
}

/// Due date indicator with relative formatting and overdue highlight.
class ZenTaoDueTag extends StatelessWidget {
  const ZenTaoDueTag({super.key, required this.deadline});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    if (deadline == null) {
      return Text(
        '—',
        style: context.typography.bodySm.copyWith(
          color: context.colors.textTertiary,
        ),
      );
    }

    final d = deadline!;
    final c = context.colors;
    final l = AppL10n.of(context);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(d.year, d.month, d.day);
    final diff = targetDay.difference(today).inDays;
    final isToday = diff == 0;
    final isOverdue = diff < 0;

    final String text;
    if (isToday) {
      text = l.datePickToday;
    } else if (diff > 0 && diff < 7) {
      text = DateFormat.E(locale).format(d);
    } else {
      text = DateFormat.MMMd(locale).format(d);
    }

    final color = isOverdue ? c.error : c.textSecondary;

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.typography.bodySm.copyWith(
        color: color,
        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// Semantic status pill for task list rows.
class ZenTaoRowStatusPill extends StatelessWidget {
  const ZenTaoRowStatusPill({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    final (label, bg, fg) = switch (zentaoTaskColumnFor(ticket)) {
      ZenTaoTaskColumn.notStarted => (
        l.boardTaskColNotStarted,
        c.surfaceSubtle,
        c.textSecondary,
      ),
      ZenTaoTaskColumn.inProgress => (
        l.boardTaskColInProgress,
        c.mixT(c.accent, 0.12),
        c.accent,
      ),
      ZenTaoTaskColumn.paused => (
        l.boardTaskColPaused,
        c.mixT(c.warning, 0.15),
        c.warning,
      ),
      ZenTaoTaskColumn.doneVerify || ZenTaoTaskColumn.closed => (
        l.colDone,
        c.mixT(c.success, 0.15),
        c.success,
      ),
      ZenTaoTaskColumn.canceled => (
        l.boardTaskColCanceled,
        c.mixT(c.error, 0.12),
        c.error,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.sm, vertical: s.xxs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(context.radii.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.caption.copyWith(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Assignee display with circular initials avatar and name.
class ZenTaoRowAssigneeDisplay extends StatelessWidget {
  const ZenTaoRowAssigneeDisplay({
    super.key,
    required this.assignee,
    required this.palette,
    required this.unassignedLabel,
  });

  final String? assignee;
  final List<Color> palette;
  final String unassignedLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final name = assignee?.trim() ?? '';

    if (name.isEmpty) {
      return Text(
        unassignedLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.typography.bodySm.copyWith(color: c.textTertiary),
      );
    }

    final words = name.split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : (name.length >= 2
              ? name.substring(0, 2).toUpperCase()
              : name.toUpperCase());

    final avatarColor = palette[name.hashCode.abs() % palette.length];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: s.xs),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.bodySm.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}
