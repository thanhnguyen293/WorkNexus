import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_count_badge.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/group_my_work.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import '../util/my_work_status.dart';
import 'dashboard_work_header.dart';
import 'my_work_row.dart';

/// Every bug or task assigned to the user — the full list behind the
/// overview, under [DashboardWorkHeader] — in status sections (in progress first, finished last). Reads
/// the shared ticket store (synced from ZenTao on open), so rows open
/// straight in the detail panel. Open items by default.
class DashboardWorkView extends ConsumerWidget {
  const DashboardWorkView({
    super.key,
    required this.account,
    required this.kind,
  });

  final Account account;
  final DashboardItemKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final l = AppL10n.of(context);
    final sync = ref.watch(myWorkSyncProvider(account.id));
    final openOnly = ref.watch(dashboardWorkOpenOnlyProvider);
    MyWorkKey key({required bool open}) => (
      accountId: account.id,
      user: account.handle,
      kind: kind,
      openOnly: open,
    );
    final open = ref.watch(myWorkProvider(key(open: true)));
    final all = ref.watch(myWorkProvider(key(open: false)));
    final groups = const GroupMyWork()(openOnly ? open : all);
    final failed = sync.hasError && !sync.isLoading;
    void retry() => ref.read(myWorkSyncProvider(account.id).notifier).refresh();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // With rows to show, a failed sync keeps them and says so above.
        if (failed && groups.isNotEmpty) ...[
          AppInlineNote(text: l.dashboardWorkSyncFailed, isError: true),
          SizedBox(height: s.xl),
        ],
        Expanded(
          child: groups.isNotEmpty
              ? ListView.separated(
                  key: PageStorageKey('dashboard-work-${kind.name}'),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => SizedBox(height: s.xl4),
                  itemBuilder: (_, i) => _Section(
                    group: groups[i],
                    bug: kind == DashboardItemKind.bug,
                  ),
                )
              : sync.isLoading
              ? const AppStateView.loading()
              : failed
              ? AppStateView.error(onRetry: retry)
              : AppStateView.empty(
                  icon: LucideIcons.circleCheck300,
                  title: openOnly
                      ? l.dashboardFocusEmpty
                      : l.dashboardWorkEmptyAll,
                ),
        ),
      ],
    );
  }
}

/// One status section: its dot, name and count over a card of rows.
class _Section extends StatelessWidget {
  const _Section({required this.group, required this.bug});

  final MyWorkGroup group;
  final bool bug;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final color = myWorkStatusColor(c, group.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(s.xs, 0, s.xs, s.md),
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
                  myWorkStatusLabel(l, group.status, bug: bug).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.labelWide.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
              SizedBox(width: s.sm),
              AppCountBadge(group.tickets.length),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.all(s.xs),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.lg),
            border: Border.fromBorderSide(context.hairlineSide),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, Ticket ticket) in group.tickets.indexed) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: s.xl6 + s.md,
                    color: c.border,
                  ),
                MyWorkRow(ticket: ticket, showStatus: false),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
