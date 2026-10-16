import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/usecases/rank_dashboard_executions.dart';
import 'dashboard_activity_list.dart';
import 'dashboard_card.dart';
import 'dashboard_execution_list.dart';
import 'dashboard_work_list.dart';

/// The cards built from the stored ZenTao dashboard. Each shows only the
/// first few items, so cards side by side stay close in height and the
/// Overview stays short; the count badge keeps the full total.

/// Rows shown in the activity and todo cards.
const _maxRows = 5;

/// The ZenTao tool's Executions tab, which "Show all" opens.
const _executionsSection = SectionId('zentao.sprints');

/// The few executions worth a glance (running, ending soonest), with "Show
/// all" opening the ZenTao Executions tab.
class DashboardExecutionsCard extends ConsumerWidget {
  const DashboardExecutionsCard({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final module = ref.watch(toolRegistryProvider)[account.providerType];
    final opensTab =
        module?.sections.any((sec) => sec.id == _executionsSection) ?? false;
    return DashboardCard(
      title: l.dashboardSprints,
      icon: LucideIcons.kanban300,
      count: dashboard.executionTotal,
      action: module != null && opensTab
          ? AppButton.text(
              size: AppButtonSize.small,
              onPressed: () {
                final nav = ref.read(appNavProvider.notifier);
                nav.selectAccount(account.id, module: module);
                nav.selectSection(_executionsSection, module: module);
              },
              child: Text(l.dashboardShowAll),
            )
          : null,
      child: DashboardExecutionList(
        executions: const RankDashboardExecutions()(dashboard.executions),
      ),
    );
  }
}

/// The latest few events on the account's ZenTao.
class DashboardActivityCard extends StatelessWidget {
  const DashboardActivityCard({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return DashboardCard(
      title: AppL10n.of(context).dashboardActivity,
      icon: LucideIcons.history300,
      padding: EdgeInsets.fromLTRB(s.md, s.xl, s.md, s.sm),
      child: DashboardActivityList(
        account: account,
        activities: dashboard.activities.take(_maxRows).toList(),
      ),
    );
  }
}

/// The user's first few personal todos.
class DashboardTodosCard extends StatelessWidget {
  const DashboardTodosCard({
    super.key,
    required this.account,
    required this.dashboard,
  });

  final Account account;
  final ZenTaoDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return DashboardCard(
      title: AppL10n.of(context).dashboardTodos,
      icon: LucideIcons.listChecks300,
      count: dashboard.todoTotal,
      padding: EdgeInsets.fromLTRB(s.sm, s.md, s.sm, s.md),
      child: DashboardWorkList(
        account: account,
        items: dashboard.todos.take(_maxRows).toList(),
      ),
    );
  }
}
