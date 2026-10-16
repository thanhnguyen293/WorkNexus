import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_grid.dart';
import 'dashboard_queue.dart';
import 'dashboard_snapshot_cards.dart';

/// A ZenTao account's dashboard on the Overview: My tasks beside My bugs
/// (read from the ticket store), then executions beside recent activity
/// (from the stored dashboard, refreshed in the background when stale).
/// Cards side by side share a height; below [twoColumnWidth] they stack.
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
            DashboardGrid(
              wide: wide,
              cells: [
                DashboardQueue(account: account, kind: DashboardItemKind.task),
                DashboardQueue(account: account, kind: DashboardItemKind.bug),
              ],
            ),
            SizedBox(height: s.xl),
            if (dashboard != null) ...[
              if (failed) ...[
                AppInlineNote(text: l.dashboardRefreshFailed, isError: true),
                SizedBox(height: s.md),
              ],
              DashboardGrid(
                wide: wide,
                cells: [
                  if (dashboard.executions.isNotEmpty)
                    DashboardExecutionsCard(
                      account: account,
                      dashboard: dashboard,
                    ),
                  if (dashboard.activities.isNotEmpty)
                    DashboardActivityCard(
                      account: account,
                      dashboard: dashboard,
                    ),
                  if (dashboard.todos.isNotEmpty)
                    DashboardTodosCard(account: account, dashboard: dashboard),
                ],
              ),
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
