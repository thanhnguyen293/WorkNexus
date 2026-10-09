import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_segmented.dart';

/// The full list's header: back to the overview, which list (tasks or bugs,
/// switchable in place), open-only or everything, and refresh.
class DashboardWorkHeader extends ConsumerWidget {
  const DashboardWorkHeader({
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
    final syncing = ref.watch(myWorkSyncProvider(account.id)).isLoading;
    final openOnly = ref.watch(dashboardWorkOpenOnlyProvider);
    final work = ref.watch(workQueueProvider(account));
    int count({required bool open}) => ref
        .watch(
          myWorkProvider((
            accountId: account.id,
            user: account.handle,
            kind: kind,
            openOnly: open,
          )),
        )
        .length;
    final bug = kind == DashboardItemKind.bug;
    return Wrap(
      spacing: s.xl,
      runSpacing: s.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () =>
                  ref.read(dashboardWorkKindProvider.notifier).state = null,
              icon: Icon(PhosphorIconsLight.arrowLeft, color: c.textSecondary),
            ),
            SizedBox(width: s.sm),
            ZenTaoKindIcon(kind.name, large: true),
            SizedBox(width: s.lg),
            Text(
              bug ? l.dashboardAllBugs : l.dashboardAllTasks,
              style: t.display.copyWith(color: c.textPrimary),
            ),
          ],
        ),
        DashboardSegmented<DashboardItemKind>(
          selected: kind,
          onChanged: (k) =>
              ref.read(dashboardWorkKindProvider.notifier).state = k,
          segments: [
            (
              value: DashboardItemKind.task,
              label: l.dashboardTasksTab,
              count: work.openTasks,
            ),
            (
              value: DashboardItemKind.bug,
              label: l.dashboardBugsTab,
              count: work.openBugs,
            ),
          ],
        ),
        DashboardSegmented<bool>(
          selected: openOnly,
          onChanged: (v) =>
              ref.read(dashboardWorkOpenOnlyProvider.notifier).state = v,
          segments: [
            (value: true, label: l.dashboardOpenOnly, count: count(open: true)),
            (
              value: false,
              label: l.dashboardAllItems,
              count: count(open: false),
            ),
          ],
        ),
        IconButton(
          tooltip: l.refresh,
          onPressed: syncing
              ? null
              : () =>
                    ref.read(myWorkSyncProvider(account.id).notifier).refresh(),
          icon: syncing
              ? SizedBox.square(
                  dimension: s.xl3,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(PhosphorIconsLight.arrowClockwise, color: c.textSecondary),
        ),
      ],
    );
  }
}
