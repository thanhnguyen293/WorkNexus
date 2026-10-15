import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/overview_providers.dart';
import '../widgets/assigned_work_list.dart';
import '../widgets/tool_card.dart';

/// The Workspace Overview page (design §5, specs S6.1).
/// Displays connected tools in a responsive card grid and open assigned work.
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

    return ColoredBox(
      color: c.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl5, s.xl4, s.xl5, s.xl5),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OverviewHeader(
                  accountCount: accounts.length,
                  workspaceName: wsName,
                ),
                SizedBox(height: s.xl4),
                _ToolCardGrid(accounts: accounts),
                SizedBox(height: s.xl4),
                const AssignedWorkList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewHeader extends ConsumerWidget {
  const _OverviewHeader({
    required this.accountCount,
    required this.workspaceName,
  });

  final int accountCount;
  final String workspaceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.overview,
                style: context.typography.display.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: s.xs),
              Text(
                l.overviewSubtitle(accountCount, workspaceName),
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: s.lg),
        AppButton.text(
          onPressed: () => ref
              .read(appNavProvider.notifier)
              .selectWorkspaceSection(WorkspaceSection.integrations),
          child: Text(l.manageIntegrations),
        ),
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
        final int columns = availableWidth >= 840
            ? 3
            : availableWidth >= 560
            ? 2
            : 1;
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
