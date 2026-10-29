import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/dashboard_providers.dart';
import '../providers/overview_providers.dart';
import '../widgets/assigned_work_list.dart';
import '../widgets/tool_card.dart';
import '../widgets/zentao_overview_section.dart';
import 'dashboard_work_page.dart';

/// The Workspace Overview page (design §5, specs S6.1).
/// Displays the connected tools as compact cards filling one row, then a
/// dashboard section per ZenTao account, then the open assigned work.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key, this.onConnect});

  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final activeWs = ref.watch(activeWorkspaceProvider);
    final accounts = ref.watch(workspaceAccountsProvider);
    final wsName = activeWs?.name ?? '';

    if (accounts.isEmpty) {
      return ColoredBox(
        color: c.background,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(s.xl4),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sizes.stateMessage),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: context.sizes.stateTile,
                    height: context.sizes.stateTile,
                    decoration: BoxDecoration(
                      color: c.surfaceSubtle,
                      borderRadius: BorderRadius.circular(context.radii.md),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.plug300,
                      size: context.sizes.iconXl,
                      color: c.textSecondary,
                    ),
                  ),
                  SizedBox(height: s.md),
                  Text(
                    l.noConnectedAccounts,
                    textAlign: TextAlign.center,
                    style: context.typography.title.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: s.xs),
                  Text(
                    l.noConnectedAccountsDesc,
                    textAlign: TextAlign.center,
                    style: context.typography.paragraph.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  SizedBox(height: s.lg),
                  AppButton.filled(
                    onPressed:
                        onConnect ??
                        () => ref
                            .read(appNavProvider.notifier)
                            .selectWorkspaceSection(
                              WorkspaceSection.integrations,
                            ),
                    child: Text(l.connectATool),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // "Show all" of a ZenTao section opens the account's full lists in the
    // Overview's place, until their back button (or a workspace without that
    // account) brings the Overview back.
    final target = ref.watch(myWorkTargetProvider);
    final targetAccount = accounts
        .where((a) => a.id == target?.account.id)
        .firstOrNull;
    if (target != null && targetAccount != null) {
      return DashboardWorkPage(account: targetAccount, kind: target.kind);
    }

    // Every tool has a compact card in the top row; a ZenTao account also
    // gets its dashboard as a section below the row.
    final zentao = [
      for (final a in accounts)
        if (a.providerType == ProviderType.zentao) a,
    ];

    return AppPage(
      title: l.overview,
      subtitle: l.overviewSubtitle(accounts.length, wsName),
      trailing: AppButton.text(
        onPressed: () => ref
            .read(appNavProvider.notifier)
            .selectWorkspaceSection(WorkspaceSection.integrations),
        child: Text(l.manageIntegrations),
      ),
      children: [
        _ToolCardGrid(accounts: accounts),
        for (final account in zentao) ZenTaoOverviewSection(account: account),
        const AssignedWorkList(),
      ],
    );
  }
}

class _ToolCardGrid extends StatelessWidget {
  const _ToolCardGrid({required this.accounts});

  final List<Account> accounts;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int fits = availableWidth >= 840
            ? 3
            : availableWidth >= 560
            ? 2
            : 1;
        // Fewer tools than columns: the cards share the row instead of
        // leaving columns empty.
        final columns = accounts.length.clamp(1, fits);
        final totalSpacing = s.lg * (columns - 1);
        final itemWidth = (availableWidth - totalSpacing) / columns;

        return Wrap(
          spacing: s.lg,
          runSpacing: s.lg,
          children: [
            for (final account in accounts)
              SizedBox(
                width: itemWidth,
                child: ToolCard(account: account),
              ),
          ],
        );
      },
    );
  }
}
