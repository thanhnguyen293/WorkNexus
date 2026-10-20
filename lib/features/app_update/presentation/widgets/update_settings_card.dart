import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/build_issue_report_url.dart';
import '../providers/auto_update_controller.dart';
import '../providers/update_controller.dart';
import '../providers/update_provider.dart';
import 'update_dialog.dart';

class UpdateSettingsCard extends ConsumerStatefulWidget {
  const UpdateSettingsCard({super.key});

  @override
  ConsumerState<UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends ConsumerState<UpdateSettingsCard> {
  /// The manual check's spinner; the controller's state tracks the install,
  /// not the lookup.
  var _checking = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
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
                    isLoading: _checking,
                    onPressed: _checkForUpdates,
                    icon: LucideIcons.rotateCw300,
                    child: Text(l.checkForUpdates),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.lg),
              const _AutoUpdateRow(),
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
                    icon: LucideIcons.bug300,
                    child: Text(l.reportIssue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    final result = await ref.read(updateControllerProvider.notifier).check();
    if (!mounted) return;
    setState(() => _checking = false);

    final l = AppL10n.of(context);
    result.fold<void>((update) {
      if (update == null) {
        showAppSnack(context, l.latestVersionInstalled);
        return;
      }
      // One dialog per check: the controller is already downloading.
      showDialog<void>(
        context: context,
        builder: (_) => UpdateDialog(update: update),
      );
    }, (_) => showAppSnack(context, l.updateCheckFailed, isError: true));
  }
}

/// The switch for background updates, with what it does underneath.
class _AutoUpdateRow extends ConsumerWidget {
  const _AutoUpdateRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    // On until the saved choice is read: that is what a build that never
    // saved one does.
    final on = ref.watch(autoUpdateProvider).asData?.value ?? true;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.autoUpdateLabel,
                style: context.typography.body.copyWith(color: c.textPrimary),
              ),
              SizedBox(height: context.spacing.xxs),
              Text(
                l.autoUpdateHint,
                style: context.typography.paragraph.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.spacing.lg),
        Switch(
          value: on,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            final saved = await ref
                .read(autoUpdateProvider.notifier)
                .set(value);
            if (saved.isErr) {
              showAppSnackOn(messenger, l.autoUpdateSaveFailed, isError: true);
            }
          },
        ),
      ],
    );
  }
}
