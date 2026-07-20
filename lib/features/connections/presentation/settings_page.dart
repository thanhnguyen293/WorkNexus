import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../l10n/app_localizations.dart';
import 'add_connection_dialog.dart';
import 'github_connection_dialog.dart';
import 'gitlab_connection_dialog.dart';
import 'settings_providers.dart';
import 'widgets/account_list.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.connectedAccounts,
                              style: context.typography.titleLg.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                            SizedBox(height: context.spacing.xs),
                            Text(
                              'The same provider can be connected multiple times — one per company. '
                              'Tasks assigned to you are pulled from every account below.',
                              style: context.typography.paragraph.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.spacing.xl3),
                      AppButton.filled(
                        onPressed: () => ref
                            .read(connectPickerOpenProvider.notifier)
                            .update((v) => !v),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 16),
                            SizedBox(width: context.spacing.sm),
                            Text(l.connect),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (pickerOpen) ...[
                    SizedBox(height: context.spacing.xl3),
                    _ProviderPicker(),
                  ],
                  SizedBox(height: context.spacing.xl4),
                  for (final w in workspaces)
                    WorkspaceAccounts(workspaceId: w.id, lookups: lookups),
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
        borderRadius: BorderRadius.circular(context.radii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _uppercase(context, l.chooseProvider),
          SizedBox(height: context.spacing.lg),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${p.displayName} adapter coming soon',
                              ),
                            ),
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

Widget _uppercase(BuildContext context, String text) => Text(
  text.toUpperCase(),
  style: context.typography.caption.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: context.colors.textTertiary,
  ),
);
