import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../../../../core/widgets/badges.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_body.dart';
import 'dashboard_sync_status.dart';
import 'tool_card_parts.dart';

/// A ZenTao account's dashboard on the Overview, as one inset panel: a
/// heading (logo, "ZenTao · account", sync status, "Open ZenTao →") over My
/// tasks / My bugs, then executions / recent activity. The account-wide
/// numbers stay on its compact card in the row above. Shows what is stored at
/// once; the assigned work syncs once per session in the background and the
/// dashboard refetches only when stale.
class ZenTaoOverviewSection extends ConsumerWidget {
  const ZenTaoOverviewSection({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final module = ref.watch(toolRegistryProvider)[account.providerType];
    if (module == null) return const SizedBox.shrink();
    // Starts the background sync of the assigned work; one already running
    // for the account (the launch sync) is shared, not repeated.
    ref.watch(myWorkSyncProvider(account.id));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceSubtle,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.fromBorderSide(context.hairlineSide),
      ),
      child: Padding(
        padding: EdgeInsets.all(s.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(account: account, module: module),
            SizedBox(height: s.xl),
            DashboardBody(account: account),
          ],
        ),
      ),
    );
  }
}

/// Logo and "ZenTao · account" leading; sync status and "Open ZenTao →" at
/// the trailing edge, or on a line of their own when narrow.
class _Heading extends ConsumerWidget {
  const _Heading({required this.account, required this.module});

  /// Below this width the actions move under the title.
  static const double _inlineActionsWidth = 560;

  final Account account;
  final ToolModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final fetchedAt = ref.watch(dashboardProvider(account.id)).value?.fetchedAt;
    final title = Row(
      children: [
        ProviderBadge(account.providerType, big: true),
        SizedBox(width: s.md),
        Expanded(
          child: Text(
            '${account.providerType.displayName} · ${account.handle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.typography.titleSm.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
    // Right-aligned in the space left, so it sits by the open button.
    final trailingStatus = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: DashboardSyncStatus(account: account, fetchedAt: fetchedAt),
    );
    final open = ToolOpenButton(account: account, module: module);
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= _inlineActionsWidth
          ? Row(
              children: [
                Expanded(child: title),
                SizedBox(width: s.lg),
                Expanded(child: trailingStatus),
                SizedBox(width: s.md),
                open,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                SizedBox(height: s.md),
                Row(
                  children: [
                    open,
                    SizedBox(width: s.md),
                    Expanded(child: trailingStatus),
                  ],
                ),
              ],
            ),
    );
  }
}
