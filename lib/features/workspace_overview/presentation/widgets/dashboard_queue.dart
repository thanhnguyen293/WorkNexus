import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_card.dart';
import 'my_work_row.dart';

/// The user's open tasks or open bugs of one account — in progress, then
/// not started, the most urgent on top — with "Show all" opening the full
/// list in place of the Overview.
class DashboardQueue extends ConsumerWidget {
  const DashboardQueue({super.key, required this.account, required this.kind});

  final Account account;
  final DashboardItemKind kind;

  /// Rows per group before the full list takes over.
  static const _perGroup = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final bug = kind == DashboardItemKind.bug;
    final queue = ref.watch(
      myWorkQueueProvider((account: account, kind: kind)),
    );
    final sync = ref.watch(myWorkSyncProvider(account.id));
    final empty = queue.inProgress.isEmpty && queue.notStarted.isEmpty;
    return DashboardCard(
      title: bug ? l.dashboardMyBugs : l.dashboardMyTasks,
      icon: bug ? LucideIcons.bug300 : LucideIcons.clipboardList300,
      count: queue.inProgress.length + queue.notStarted.length,
      action: AppButton.text(
        size: AppButtonSize.small,
        onPressed: () => ref.read(myWorkTargetProvider.notifier).state = (
          account: account,
          kind: kind,
        ),
        child: Text(l.dashboardShowAll),
      ),
      padding: EdgeInsets.fromLTRB(s.sm, s.md, s.sm, s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (empty && sync.isLoading)
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.all(s.md),
                child: SkeletonBox(height: s.xl6),
              )
          else if (empty && sync.hasError)
            AppStateView.error(
              compact: true,
              onRetry: () =>
                  ref.read(myWorkSyncProvider(account.id).notifier).refresh(),
            )
          else if (empty)
            AppStateView.empty(
              compact: true,
              icon: LucideIcons.circleCheck300,
              title: l.dashboardFocusEmpty,
            ),
          if (queue.inProgress.isNotEmpty)
            _Group(
              title: l.dashboardInProgress,
              color: c.caution,
              tickets: queue.inProgress.take(_perGroup).toList(),
              total: queue.inProgress.length,
            ),
          if (queue.notStarted.isNotEmpty)
            _Group(
              title: l.dashboardNotStarted,
              color: c.accent,
              tickets: queue.notStarted.take(_perGroup).toList(),
              total: queue.notStarted.length,
            ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.color,
    required this.tickets,
    required this.total,
  });

  final String title;
  final Color color;
  final List<Ticket> tickets;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(s.md, s.md, s.md, s.xs),
          child: Row(
            children: [
              Container(
                width: s.md,
                height: s.md,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: s.md),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.labelWide.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
              SizedBox(width: s.sm),
              AppCountBadge(total),
            ],
          ),
        ),
        for (final ticket in tickets)
          MyWorkRow(ticket: ticket, showStatus: false),
      ],
    );
  }
}
