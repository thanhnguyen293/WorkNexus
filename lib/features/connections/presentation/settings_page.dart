import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/badges.dart';
import '../../../l10n/app_localizations.dart';
import 'add_connection_dialog.dart';
import 'github_connection_dialog.dart';
import 'gitlab_connection_dialog.dart';
import 'settings_providers.dart';
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
    final pickerOpen = ref.watch(connectPickerOpenProvider);

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
                      onPressed: () => ref
                          .read(connectPickerOpenProvider.notifier)
                          .update((v) => !v),
                      child: Text(l.connect),
                    ),
                  ),
                  if (pickerOpen) ...[
                    SizedBox(height: context.spacing.xl3),
                    _ProviderPicker(),
                  ],
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

class _ProviderPicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Container(
      padding: EdgeInsets.all(context.spacing.xl2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: l.chooseProvider),
          SizedBox(height: context.spacing.md),
          Row(
            children: [
              for (final p in ProviderType.values) ...[
                Expanded(
                  child: AppButton.outlinedNeutral(
                    size: AppButtonSize.large,
                    onPressed: () {
                      switch (p) {
                        case ProviderType.zentao:
                          AddConnectionDialog.show(context);
                        case ProviderType.gitlab:
                          GitLabConnectionDialog.show(context);
                        case ProviderType.github:
                          GitHubConnectionDialog.show(context);
                        case ProviderType.jira:
                          showAppSnack(
                            context,
                            l.connectionsProviderComingSoon(p.displayName),
                          );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ProviderBadge(p, big: true),
                        SizedBox(width: context.spacing.md),
                        Flexible(
                          child: Text(
                            p.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: context.typography.bodySm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: context.spacing.md),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
