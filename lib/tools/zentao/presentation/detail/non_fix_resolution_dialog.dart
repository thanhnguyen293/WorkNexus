import 'package:flutter/material.dart';

import '../../../../core/domain/value_objects/zentao_bug_column.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dialog_frame.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../../l10n/app_localizations.dart';

/// Asks which non-fix resolution a bug dropped on the Non-Fix column gets.
/// Pops the resolution code, or null when dismissed.
class NonFixResolutionDialog extends StatefulWidget {
  const NonFixResolutionDialog({super.key});

  @override
  State<NonFixResolutionDialog> createState() => _NonFixResolutionDialogState();
}

class _NonFixResolutionDialogState extends State<NonFixResolutionDialog> {
  String? _resolution;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final resolution = _resolution;
    return AppDialogFrame(
      title: l.boardNonFixTitle,
      maxWidth: context.sizes.dialogSm,
      actions: [
        const Spacer(),
        AppButton.textNeutral(
          size: AppButtonSize.small,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        AppButton.filled(
          size: AppButtonSize.small,
          onPressed: resolution == null
              ? null
              : () => Navigator.of(context).pop(resolution),
          child: Text(l.resolve),
        ),
      ],
      child: Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, 0, s.xl3, s.xl3),
        // Nothing is picked up front: a preselected reason would be one
        // careless click away from the wrong resolution.
        child: AppDropdown<String?>(
          value: resolution,
          values: zentaoNonFixResolutionLabels.keys.toList(),
          labelOf: (code) => code == null
              ? l.boardNonFixReasonHint
              : zentaoNonFixResolutionLabels[code] ?? code,
          onChanged: (code) => setState(() => _resolution = code),
        ),
      ),
    );
  }
}
