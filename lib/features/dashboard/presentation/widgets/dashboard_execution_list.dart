import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/dashboard_execution.dart';
import '../util/dashboard_status_color.dart';
import 'my_work_meta.dart';

/// The user's unfinished executions (sprints): name, project and status over
/// a progress bar, then when it ends and how many days are left.
class DashboardExecutionList extends StatelessWidget {
  const DashboardExecutionList({super.key, required this.executions});

  final List<DashboardExecution> executions;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < executions.length; i++) ...[
          if (i > 0) SizedBox(height: s.xl3),
          _Execution(executions[i]),
        ],
      ],
    );
  }
}

class _Execution extends StatelessWidget {
  const _Execution(this.execution);

  final DashboardExecution execution;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
    final l = AppL10n.of(context);
    final e = execution;
    final project = e.projectName;
    final percent = e.progress;
    final value = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    final status = e.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                e.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: c.textPrimary),
              ),
            ),
            if (status != null) ...[
              SizedBox(width: s.md),
              MyWorkStatusChip(
                label: _statusLabel(l, status),
                color: dashboardStatusColor(c, status),
              ),
            ],
          ],
        ),
        // The project only adds information when named differently.
        if (project != null && project != e.name)
          Padding(
            padding: EdgeInsets.only(top: s.xxs),
            child: Text(
              project,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: c.textTertiary),
            ),
          ),
        SizedBox(height: s.md),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.radii.pill),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: s.sm,
                  color: value >= 1 ? c.success : c.accent,
                  backgroundColor: c.surfaceSubtle,
                ),
              ),
            ),
            if (percent != null) ...[
              SizedBox(width: s.md),
              Text(
                '${percent.round()}%',
                style: t.bodySmStrong.copyWith(
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
        if (e.end case final end?) ...[SizedBox(height: s.sm), _EndLine(end)],
      ],
    );
  }

  static String _statusLabel(AppL10n l, String status) => switch (status) {
    'wait' => l.myWorkStatusWaiting,
    'doing' => l.myWorkStatusDoing,
    'suspended' => l.myWorkStatusPaused,
    'closed' => l.myWorkStatusClosed,
    _ => status,
  };
}

/// "Ends Oct 20 · 11 days left", the countdown red once past the end.
class _EndLine extends StatelessWidget {
  const _EndLine(this.end);

  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(end.year, end.month, end.day).difference(today);
    final overdue = days.isNegative;
    return Row(
      children: [
        MyWorkFact(
          icon: LucideIcons.flag300,
          text: l.dashboardEnds(DateFormat.MMMd(locale).format(end)),
        ),
        const Spacer(),
        Text(
          overdue
              ? l.dashboardDaysOverdue(-days.inDays)
              : l.dashboardDaysLeft(days.inDays),
          style: context.typography.captionStrong.copyWith(
            color: overdue
                ? c.error
                : days.inDays <= 3
                ? c.warning
                : c.textSecondary,
          ),
        ),
      ],
    );
  }
}
