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
import '../widgets/integration_row.dart';

/// The Integrations page for the active workspace (design §5, specs S6.2).
/// Displays connected accounts with health pills, a Connect Tool button,
/// and a text-only permission info box (no checkbox).
class IntegrationsPage extends ConsumerWidget {
  const IntegrationsPage({super.key, this.onConnect, this.onManageAccount});

  final VoidCallback? onConnect;
  final void Function(BuildContext context, Account account)? onManageAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final activeWs = ref.watch(activeWorkspaceProvider);
    final accounts = ref.watch(workspaceAccountsProvider);
    final wsName = activeWs?.name ?? '';

    return ColoredBox(
      color: c.background,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(s.xl5, s.xl4, s.xl5, s.xl5),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IntegrationsHeader(onConnect: onConnect),
                SizedBox(height: s.xl4),
                _ConnectedAccountsCard(
                  accounts: accounts,
                  onManageAccount: onManageAccount,
                ),
                SizedBox(height: s.xl4),
                _WhoCanConnectInfoBox(workspaceName: wsName),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntegrationsHeader extends StatelessWidget {
  const _IntegrationsHeader({this.onConnect});

  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
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
                l.integrations,
                style: context.typography.display.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: s.xs),
              Text(
                l.connectionsSettingsSubtitle,
                style: context.typography.bodySm.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: s.lg),
        AppButton.filled(
          key: const ValueKey('connect-tool-button'),
          icon: LucideIcons.plus300,
          onPressed: onConnect,
          child: Text(l.connectATool),
        ),
      ],
    );
  }
}

class _ConnectedAccountsCard extends StatelessWidget {
  const _ConnectedAccountsCard({required this.accounts, this.onManageAccount});

  final List<Account> accounts;
  final void Function(BuildContext context, Account account)? onManageAccount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(r.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.lg),
            child: Text(
              l.connectedWithCount(accounts.length),
              style: context.typography.bodyStrong.copyWith(
                color: c.textPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: c.border),
          if (accounts.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.xl3),
              child: Center(
                child: Text(
                  l.noConnectedAccounts,
                  style: context.typography.bodySm.copyWith(
                    color: c.textTertiary,
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < accounts.length; i++) ...[
              if (i > 0) Divider(height: 1, color: c.border),
              IntegrationRow(
                account: accounts[i],
                onManage: onManageAccount != null
                    ? () => onManageAccount!(context, accounts[i])
                    : null,
              ),
            ],
        ],
      ),
    );
  }
}

class _WhoCanConnectInfoBox extends StatelessWidget {
  const _WhoCanConnectInfoBox({required this.workspaceName});

  final String workspaceName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final r = context.radii;
    final l = AppL10n.of(context);

    return Container(
      padding: EdgeInsets.all(s.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(r.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.info300,
                size: context.sizes.iconSm,
                color: c.textSecondary,
              ),
              SizedBox(width: s.sm),
              Text(
                l.whoCanConnectTools,
                style: context.typography.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: s.sm),
          Text(
            l.connectionsSharedByEveryone(workspaceName),
            style: context.typography.bodySm.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
