import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/badges.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_card.dart';
import 'my_work_row.dart';

/// The open work as one queue in two groups — in progress, then not
/// started — with bugs and tasks mixed and the most urgent on top. The
/// footer opens the full task and bug lists.
class DashboardQueue extends ConsumerWidget {
  const DashboardQueue({super.key, required this.account});

  final Account account;

  /// Rows per group before the full list takes over.
  static const _perGroup = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final work = ref.watch(workQueueProvider(account));
    final queue = work.queue;
    final syncing = ref.watch(myWorkSyncProvider(account.id)).isLoading;
    final empty = queue.inProgress.isEmpty && queue.notStarted.isEmpty;
    void open(DashboardItemKind kind) =>
        ref.read(dashboardWorkKindProvider.notifier).state = kind;
    return DashboardCard(
      title: l.dashboardMyWork,
      icon: LucideIcons.inbox300,
      count: work.openBugs + work.openTasks,
      padding: EdgeInsets.fromLTRB(s.sm, s.md, s.sm, s.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (empty && syncing)
            for (var i = 0; i < 4; i++)
              Padding(
                padding: EdgeInsets.all(s.md),
                child: SkeletonBox(height: s.xl6),
              )
          else if (empty)
            Padding(
              padding: EdgeInsets.all(s.xl6),
              child: Center(
                child: Text(
                  l.dashboardFocusEmpty,
                  style: context.typography.body.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
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
          Divider(height: s.xl, thickness: 1, color: c.border),
          Row(
            children: [
              _FooterButton(
                icon: LucideIcons.clipboardList300,
                label: l.dashboardAllTasks,
                onPressed: () => open(DashboardItemKind.task),
              ),
              _FooterButton(
                icon: LucideIcons.bug300,
                label: l.dashboardAllBugs,
                onPressed: () => open(DashboardItemKind.bug),
              ),
            ],
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
              Text(
                title.toUpperCase(),
                style: context.typography.labelWide.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(width: s.sm),
              DashboardCountBadge(total),
            ],
          ),
        ),
        for (final ticket in tickets)
          MyWorkRow(ticket: ticket, showStatus: false),
      ],
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: context.spacing.xl3),
    label: Text(label),
  );
}
