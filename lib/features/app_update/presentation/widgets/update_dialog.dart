import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/open_external.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/markdown_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/update_controller.dart';
import '../providers/update_state.dart';

/// The downloaded release's notes, with a restart to install it — or, when
/// the in-app install could not run, a link to install it by hand.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key});

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  var _installing = false;

  Future<void> _install() async {
    setState(() => _installing = true);
    // Only returns when the install could not start; the state then says why.
    await ref.read(updateControllerProvider.notifier).installAndRestart();
    if (mounted) setState(() => _installing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final state = ref.watch(updateControllerProvider);
    final (release, failed) = switch (state) {
      UpdateReady(:final release) => (release, false),
      UpdateInstallFailed(:final release) => (release, true),
      _ => (null, false),
    };
    if (release == null) return const SizedBox.shrink();

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Text(
        l.updateDialogTitle('${release.version}'),
        style: context.typography.title.copyWith(color: c.textPrimary),
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: release.notes.trim().isEmpty
                    ? Text(
                        l.updateNoNotes,
                        style: context.typography.paragraph.copyWith(
                          color: c.textTertiary,
                        ),
                      )
                    : MarkdownText(
                        release.notes,
                        color: c.textSecondary,
                        onLinkTap: openExternally,
                      ),
              ),
            ),
            if (failed) ...[
              SizedBox(height: context.spacing.xl),
              Text(
                l.updateInstallFailed,
                style: context.typography.paragraph.copyWith(color: c.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.updateLater),
        ),
        SizedBox(width: context.spacing.md),
        if (failed)
          AppButton.filled(
            onPressed: () => openExternally(release.pageUrl),
            child: Text(l.updateOpenReleasePage),
          )
        else
          AppButton.filled(
            isLoading: _installing,
            onPressed: _install,
            child: Text(l.updateRestartNow),
          ),
      ],
    );
  }
}
