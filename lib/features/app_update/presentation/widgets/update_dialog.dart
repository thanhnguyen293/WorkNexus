import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/available_update.dart';
import '../providers/update_controller.dart';
import '../providers/update_state.dart';
import 'update_release_notes.dart';
import 'update_version_change.dart';

/// Shows [update] after a manual check: the download the controller already
/// started, then a restart into it. Without an in-app build for this platform,
/// or when the install fails, it points at the release page instead. Closing
/// it does not stop the download; the rail offers the restart once it is done.
class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({required this.update, super.key});

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final state = ref.watch(updateControllerProvider);
    final ready = state is UpdateReady;
    final failed = state is UpdateFailed;
    final manual = failed || state is UpdateManual;
    // Downloading or installing; also the moment before the download starts.
    final busy = !ready && !manual;

    return AppDialogFrame(
      title: l.updateDialogHeadline,
      // Roomy enough for release notes to read like a page.
      maxWidth: context.sizes.dialogLg,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.updateLater),
        ),
        if (manual)
          AppButton.filled(
            size: AppButtonSize.small,
            onPressed: () => openExternally(update.releaseUrl),
            child: Text(l.updateOpenReleasePage),
          )
        else
          AppButton.filled(
            size: AppButtonSize.small,
            isLoading: busy,
            onPressed: () =>
                ref.read(updateControllerProvider.notifier).installAndRestart(),
            child: Text(l.updateRestartNow),
          ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: UpdateVersionChange(
                from: update.currentVersion,
                to: update.latestVersion,
              ),
            ),
            if (update.releaseNotes.isNotEmpty) ...[
              SizedBox(height: s.xl2),
              UpdateReleaseNotes(notes: update.releaseNotes),
            ],
            SizedBox(height: s.xl2),
            if (busy)
              _Progress(state: state)
            else
              Text(
                failed
                    ? l.updateInstallFailed
                    : manual
                    ? l.updateManualInstall
                    : l.updateReadyHint,
                style: context.typography.paragraph.copyWith(
                  color: failed ? c.error : c.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final state = this.state;
    final progress = state is UpdateDownloading ? state.progress : null;
    final installing = state is UpdateInstalling;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.xl),
          child: LinearProgressIndicator(
            minHeight: context.spacing.md,
            value: installing || progress == null || progress <= 0
                ? null
                : progress,
            backgroundColor: c.surfaceSubtle,
            color: c.accent,
          ),
        ),
        SizedBox(height: context.spacing.md),
        Text(
          installing
              ? l.updateRestarting
              : '${l.updateDownloading} ${((progress ?? 0) * 100).round()}%',
          style: context.typography.paragraph.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
