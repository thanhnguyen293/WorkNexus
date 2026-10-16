import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_activity_list.dart';
import 'dashboard_card.dart';
import 'dashboard_execution_list.dart';
import 'dashboard_queue.dart';
import 'dashboard_work_list.dart';

/// A ZenTao account's dashboard on the Overview: My tasks beside My bugs
/// (read from the ticket store), then executions and todos beside recent
/// activity (from the stored dashboard, refreshed in the background when
/// stale). Below [twoColumnWidth] every card stacks.
class DashboardBody extends ConsumerWidget {
  const DashboardBody({super.key, required this.account});

  final Account account;

  /// From this width the cards sit in two columns.
  static const double twoColumnWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final dashboard = ref.watch(dashboardProvider(account.id)).value;
    final refresh = ref.watch(dashboardRefreshProvider(account.id));
    final failed = refresh.hasError && !refresh.isLoading;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= twoColumnWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Columns(
              wide: wide,
              left: [
                DashboardQueue(account: account, kind: DashboardItemKind.task),
              ],
              right: [
                DashboardQueue(account: account, kind: DashboardItemKind.bug),
              ],
            ),
            SizedBox(height: s.xl),
            if (dashboard != null) ...[
              if (failed) ...[
                AppInlineNote(text: l.dashboardRefreshFailed, isError: true),
                SizedBox(height: s.md),
              ],
              _Secondary(account: account, dashboard: dashboard, wide: wide),
            ] else if (failed)
              AppStateView.error(
                compact: true,
                title: l.dashboardLoadFailed,
                onRetry: () => ref
                    .read(dashboardRefreshProvider(account.id).notifier)
                    .refresh(),
              )
            else
              const AppStateView.loading(compact: true),
          ],
        );
      },
    );
  }
}

/// Executions and todos beside recent activity; cards without content are
/// left out.
class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.account,
    required this.dashboard,
    required this.wide,
  });

  final Account account;
  final ZenTaoDashboard dashboard;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final d = dashboard;
    return _Columns(
      wide: wide,
      left: [
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
      ],
      right: [
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
      ],
    );
  }
}

/// Two equal columns of stacked cards when [wide], else one column; a side
/// without cards leaves the other the full width.
class _Columns extends StatelessWidget {
  const _Columns({required this.wide, required this.left, required this.right});

  final bool wide;
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    if (!wide || left.isEmpty || right.isEmpty) {
      return _Stack([...left, ...right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Stack(left)),
        SizedBox(width: s.xl),
        Expanded(child: _Stack(right)),
      ],
    );
  }
}

class _Stack extends StatelessWidget {
  const _Stack(this.cards);

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) SizedBox(height: s.xl),
          card,
        ],
      ],
    );
  }
}
