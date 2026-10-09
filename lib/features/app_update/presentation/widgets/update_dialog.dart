import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/available_update.dart';
import '../providers/update_controller.dart';
import '../providers/update_state.dart';

/// Offers to download and install [update], then restarts into it. Without an
/// in-app build for this platform, or when the install fails, it points at the
/// release page instead.
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({required this.update, super.key});

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final state = ref.watch(updateControllerProvider);
    final busy = state is UpdateDownloading || state is UpdateInstalling;
    final failed = state is UpdateFailed || !update.canInstallInApp;

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Text(
        l.updateAvailable(update.latestVersion),
        style: context.typography.title.copyWith(color: c.textPrimary),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (busy) ...[
              LinearProgressIndicator(
                value: state is UpdateDownloading && state.progress > 0
                    ? state.progress
                    : null,
              ),
              SizedBox(height: context.spacing.md),
              Text(
                state is UpdateInstalling
                    ? l.updateRestarting
                    : l.updateDownloading,
                style: context.typography.paragraph.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ] else
              Text(
                failed ? l.updateInstallFailed : l.updateRestartHint,
                style: context.typography.paragraph.copyWith(
                  color: failed ? c.error : c.textSecondary,
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.updateLater),
        ),
        SizedBox(width: context.spacing.md),
        if (failed)
          AppButton.filled(
            onPressed: () => openExternally(update.releaseUrl),
            child: Text(l.updateOpenReleasePage),
          )
        else
          AppButton.filled(
            isLoading: busy,
            onPressed: () => ref
                .read(updateControllerProvider.notifier)
                .installAndRestart(update),
            child: Text(l.updateRestartNow),
          ),
      ],
    );
  }
}
