import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_dialog_frame.dart';

/// Asks before an action that can't be undone. Resolves `true` only when the
/// person confirms; Esc, the close button and Cancel all resolve `false`.
/// [destructive] paints the confirm button red (delete, remove, discard).
abstract final class AppConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
    return confirmed ?? false;
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String? confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final label = Text(
      confirmLabel ?? (destructive ? l.confirmDelete : l.confirm),
    );
    void confirm() => Navigator.pop(context, true);
    return AppDialogFrame(
      title: title,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        if (destructive)
          AppButton.error(
            size: AppButtonSize.small,
            onPressed: confirm,
            child: label,
          )
        else
          AppButton.filled(
            size: AppButtonSize.small,
            onPressed: confirm,
            child: label,
          ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        child: Text(
          message,
          style: context.typography.paragraph.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
