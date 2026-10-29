import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../l10n/app_localizations.dart';

/// The Integrations page for the active workspace (design §5, specs S6.2):
/// its connected accounts, managed in place (sync, edit, remove), a Connect
/// Tool button, and a text-only permission info box (no checkbox).
///
/// The account list belongs to the connections feature, so the shell hands
/// it in as [accounts].
class IntegrationsPage extends ConsumerWidget {
  const IntegrationsPage({super.key, required this.accounts, this.onConnect});

  final Widget accounts;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final wsName = ref.watch(activeWorkspaceProvider)?.name ?? '';
    return AppPage(
      title: l.integrations,
      subtitle: l.connectionsSettingsSubtitle,
      trailing: AppButton.filled(
        key: const ValueKey('connect-tool-button'),
        icon: LucideIcons.plus300,
        onPressed: onConnect,
        child: Text(l.connectATool),
      ),
      children: [
        accounts,
        _WhoCanConnectInfoBox(workspaceName: wsName),
      ],
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
