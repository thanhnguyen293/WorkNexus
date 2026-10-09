import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/build_issue_report_url.dart';
import '../providers/update_provider.dart';

class UpdateSettingsCard extends ConsumerWidget {
  const UpdateSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final check = ref.watch(updateCheckProvider);
    final version = ref.watch(appVersionProvider).asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.appUpdatesTitle,
          style: context.typography.titleLg.copyWith(color: c.textPrimary),
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          l.appUpdatesSubtitle,
          style: context.typography.paragraph.copyWith(color: c.textSecondary),
        ),
        SizedBox(height: context.spacing.xl2),
        Container(
          padding: EdgeInsets.all(context.spacing.xl2),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(context.radii.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      version == null
                          ? l.appVersionLabel
                          : '${l.appVersionLabel} $version',
                      style: context.typography.body.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  AppButton.outlinedNeutral(
                    isLoading: check.isLoading,
                    onPressed: () => _checkForUpdates(context, ref),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsLight.arrowClockwise, size: 16),
                        SizedBox(width: context.spacing.sm),
                        Text(l.checkForUpdates),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.reportIssueHint,
                      style: context.typography.paragraph.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  AppButton.outlinedNeutral(
                    onPressed: () => openExternally(
                      const BuildIssueReportUrl()(
                        appVersion: version ?? '',
                        system: Platform.operatingSystemVersion,
                      ).toString(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(PhosphorIconsLight.bug, size: 16),
                        SizedBox(width: context.spacing.sm),
                        Text(l.reportIssue),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    ref.invalidate(updateCheckProvider);
    final result = await ref.read(updateCheckProvider.future);
    if (!context.mounted) return;

    result.fold<void>(
      (update) {
        // A newer release is offered by UpdateNotificationListener's dialog.
        if (update == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(AppL10n.of(context).latestVersionInstalled),
              ),
            );
        }
      },
      (_) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).updateCheckFailed)),
        ),
    );
  }
}
