import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import 'dashboard_activity_list.dart';
import 'dashboard_card.dart';
import 'dashboard_execution_list.dart';
import 'dashboard_work_list.dart';

/// The overview's secondary column: sprint progress, personal todos and the
/// recent-activity timeline, each in its own card. Sections without content
/// are left out.
class DashboardRail extends StatelessWidget {
  const DashboardRail({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final d = dashboard;
    final sections = [
      if (d.executions.isNotEmpty)
        DashboardCard(
          title: l.dashboardSprints,
          icon: LucideIcons.kanban300,
          count: d.executionTotal,
          child: DashboardExecutionList(executions: d.executions),
        ),
      if (d.todos.isNotEmpty)
        DashboardCard(
          title: l.dashboardTodos,
          icon: LucideIcons.listChecks300,
          count: d.todoTotal,
          padding: EdgeInsets.fromLTRB(s.sm, s.md, s.sm, s.md),
          child: DashboardWorkList(account: account, items: d.todos),
        ),
      if (d.activities.isNotEmpty)
        DashboardCard(
          title: l.dashboardActivity,
          icon: LucideIcons.history300,
          padding: EdgeInsets.fromLTRB(s.md, s.xl, s.md, s.sm),
          child: DashboardActivityList(
            account: account,
            activities: d.activities,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: s.xl),
          sections[i],
        ],
      ],
    );
  }
}
