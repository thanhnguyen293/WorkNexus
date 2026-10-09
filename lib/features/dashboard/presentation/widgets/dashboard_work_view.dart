import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/group_my_work.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import '../util/my_work_status.dart';
import 'dashboard_card.dart';
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
    final c = context.colors;
    final s = context.spacing;
    final t = context.typography;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sync.hasError && !sync.isLoading) ...[
          AppInlineNote(text: l.dashboardWorkSyncFailed, isError: true),
          SizedBox(height: s.xl),
        ],
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: sync.isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          l.dashboardFocusEmpty,
                          style: t.body.copyWith(color: c.textTertiary),
                        ),
                )
              : ListView.separated(
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => SizedBox(height: s.xl4),
                  itemBuilder: (_, i) => _Section(
                    group: groups[i],
                    bug: kind == DashboardItemKind.bug,
                  ),
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
              Text(
                myWorkStatusLabel(l, group.status, bug: bug).toUpperCase(),
                style: context.typography.labelWide.copyWith(
                  color: c.textSecondary,
                ),
              ),
              SizedBox(width: s.sm),
              DashboardCountBadge(group.tickets.length),
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
