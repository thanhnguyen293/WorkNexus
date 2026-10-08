import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../opencode_key_controller.dart';

/// Confirms dropping one provider's OpenCode credentials. Removal is not
/// recoverable from inside the app — an OAuth login has to be redone through
/// `opencode auth login` — so it always asks first.
class OpenCodeUnlinkDialog extends ConsumerStatefulWidget {
  const OpenCodeUnlinkDialog({super.key, required this.providerId});

  final String providerId;

  static Future<void> show(
    BuildContext context, {
    required String providerId,
  }) => showDialog(
    context: context,
    builder: (_) => OpenCodeUnlinkDialog(providerId: providerId),
  );

  @override
  ConsumerState<OpenCodeUnlinkDialog> createState() =>
      _OpenCodeUnlinkDialogState();
}

class _OpenCodeUnlinkDialogState extends ConsumerState<OpenCodeUnlinkDialog> {
  @override
  void initState() {
    super.initState();
    // Clear whatever the previous write left behind, so this dialog opens on a
    // clean slate instead of a stale error or a stale "done".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(openCodeKeyControllerProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final state = ref.watch(openCodeKeyControllerProvider);

    ref.listen(openCodeKeyControllerProvider, (_, s) {
      if (s.done && context.mounted) Navigator.of(context).pop();
    });

    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radii.lg),
      ),
      title: Text(
        l.openCodeUnlinkTitle(widget.providerId),
        style: context.typography.title.copyWith(color: c.textPrimary),
      ),
      content: SizedBox(
        width: 380,
        child: Text(
          state.error ?? l.openCodeUnlinkBody,
          style: context.typography.paragraph.copyWith(
            color: state.error != null ? c.error : c.textSecondary,
          ),
        ),
      ),
      actions: [
        AppButton.textNeutral(
          onPressed: state.busy ? null : () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        SizedBox(width: context.spacing.md),
        AppButton.error(
          isLoading: state.busy,
          onPressed: state.busy
              ? null
              : () => ref
                    .read(openCodeKeyControllerProvider.notifier)
                    .remove(widget.providerId),
          child: Text(l.openCodeUnlink),
        ),
      ],
    );
  }
}
