import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../core/tools/tool_registry_provider.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_body.dart';
import 'dashboard_sync_status.dart';
import 'tool_card_metrics.dart';
import 'tool_card_parts.dart';

/// A ZenTao account on the Overview, full width: the tool card's header
/// (identity, metrics, section chips, "Open ZenTao →") over the account's
/// dashboard — My tasks, My bugs, executions and recent activity. Shows what
/// is stored at once; the assigned work syncs once per session in the
/// background and the dashboard refetches only when stale.
class ZenTaoOverviewSection extends ConsumerWidget {
  const ZenTaoOverviewSection({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.spacing;
    final module = ref.watch(toolRegistryProvider)[account.providerType];
    if (module == null) return const SizedBox.shrink();
    // Starts the background sync of the assigned work; one already running
    // for the account (the launch sync) is shared, not repeated.
    ref.watch(myWorkSyncProvider(account.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(account: account, module: module),
        SizedBox(height: s.xl),
        DashboardBody(account: account),
      ],
    );
  }
}

/// The tool card laid out across the section: identity, metrics and the
/// open action in a row, the chips and sync status under them; stacked like
/// the compact card when narrow.
class _Header extends ConsumerWidget {
  const _Header({required this.account, required this.module});

  final Account account;
  final ToolModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final fetchedAt = ref.watch(dashboardProvider(account.id)).value?.fetchedAt;
    final identity = ToolCardIdentity(account: account, module: module);
    final metrics = ToolCardMetrics(module: module, account: account);
    final chips = ToolSectionChips(account: account, module: module);
    final open = ToolOpenButton(account: account, module: module);
    final status = DashboardSyncStatus(account: account, fetchedAt: fetchedAt);
    return Container(
      padding: EdgeInsets.all(s.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= DashboardBody.twoColumnWidth
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: identity),
                      SizedBox(width: s.xl),
                      Expanded(child: metrics),
                      SizedBox(width: s.xl),
                      open,
                    ],
                  ),
                  SizedBox(height: s.lg),
                  Row(
                    children: [
                      Expanded(child: chips),
                      SizedBox(width: s.lg),
                      Flexible(child: status),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: identity),
                      SizedBox(width: s.md),
                      Flexible(child: status),
                    ],
                  ),
                  SizedBox(height: s.lg),
                  Divider(height: 1, color: c.border),
                  SizedBox(height: s.lg),
                  metrics,
                  SizedBox(height: s.lg),
                  chips,
                  SizedBox(height: s.lg),
                  open,
                ],
              ),
      ),
    );
  }
}
