import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../l10n/app_localizations.dart';
import 'connect_account_dialog.dart';
import 'widgets/account_list.dart';
import 'widgets/settings_section_heading.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({this.footer, super.key});

  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final lookups = ref.watch(lookupsProvider);

    final workspaces = lookups.workspaces.values.toList();

    return ColoredBox(
      color: c.background,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.xl5,
                context.spacing.xl5,
                context.spacing.xl5,
                context.spacing.xl6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsSectionHeading(
                    title: l.connectedAccounts,
                    subtitle: l.connectionsSettingsSubtitle,
                    trailing: AppButton.filled(
                      icon: LucideIcons.plus300,
                      onPressed: () => ConnectAccountDialog.show(context),
                      child: Text(l.connect),
                    ),
                  ),
                  SizedBox(height: context.spacing.xl4),
                  for (final w in workspaces)
                    WorkspaceAccounts(workspaceId: w.id, lookups: lookups),
                  if (footer case final footer?) ...[
                    SizedBox(height: context.spacing.xl4),
                    footer,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
