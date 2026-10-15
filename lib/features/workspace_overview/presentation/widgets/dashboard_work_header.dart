import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_work_view.dart';

/// The full lists' header: back to the overview, open-only or everything,
/// and refresh — plus, when only one list fits (see
/// [DashboardWorkView.twoColumnsMinWidth]), whether it shows tasks or bugs.
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
    int countOf(DashboardItemKind k, {required bool open}) => ref
        .watch(
          myWorkProvider((
            accountId: account.id,
            user: account.handle,
            kind: k,
            openOnly: open,
          )),
        )
        .length;
    final bug = kind == DashboardItemKind.bug;
    void showKind(DashboardItemKind k) =>
        ref.read(dashboardWorkKindProvider.notifier).state = k;
    void showOpenOnly(bool v) =>
        ref.read(dashboardWorkOpenOnlyProvider.notifier).state = v;
    return LayoutBuilder(
      builder: (context, box) {
        final both = box.maxWidth >= DashboardWorkView.twoColumnsMinWidth;
        // Side by side, the open / all counts cover both lists.
        int count({required bool open}) => both
            ? countOf(DashboardItemKind.task, open: open) +
                  countOf(DashboardItemKind.bug, open: open)
            : countOf(kind, open: open);
        return Wrap(
          spacing: s.xl,
          runSpacing: s.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIconButton(
                  icon: LucideIcons.arrowLeft300,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () =>
                      ref.read(dashboardWorkKindProvider.notifier).state = null,
                ),
                SizedBox(width: s.sm),
                Icon(
                  LucideIcons.inbox300,
                  size: context.sizes.iconLg,
                  color: c.textSecondary,
                ),
                SizedBox(width: s.lg),
                Text(
                  l.dashboardMyWork,
                  style: t.display.copyWith(color: c.textPrimary),
                ),
              ],
            ),
            if (!both)
              AppSegmentedTabs(
                tabs: [
                  AppSegmentedTab(
                    label: l.dashboardTasksTab,
                    count: work.openTasks,
                    active: kind == DashboardItemKind.task,
                    onTap: () => showKind(DashboardItemKind.task),
                  ),
                  AppSegmentedTab(
                    label: l.dashboardBugsTab,
                    count: work.openBugs,
                    active: bug,
                    onTap: () => showKind(DashboardItemKind.bug),
                  ),
                ],
              ),
            AppSegmentedTabs(
              tabs: [
                AppSegmentedTab(
                  label: l.dashboardOpenOnly,
                  count: count(open: true),
                  active: openOnly,
                  onTap: () => showOpenOnly(true),
                ),
                AppSegmentedTab(
                  label: l.dashboardAllItems,
                  count: count(open: false),
                  active: !openOnly,
                  onTap: () => showOpenOnly(false),
                ),
              ],
            ),
            AppIconButton(
              icon: LucideIcons.rotateCw300,
              tooltip: l.refresh,
              isLoading: syncing,
              onPressed: () =>
                  ref.read(myWorkSyncProvider(account.id).notifier).refresh(),
            ),
          ],
        );
      },
    );
  }
}
