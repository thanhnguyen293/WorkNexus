import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';

/// The editor's bar: back, what is being edited, why the last save failed,
/// and Save.
class EditorHeader extends StatelessWidget {
  const EditorHeader({
    super.key,
    required this.title,
    required this.kind,
    required this.onClose,
    this.onSave,
    this.saving = false,
    this.error,
  });

  final String title;

  /// The ZenTao kind being edited (`bug`, `task`), shown as its icon.
  final String kind;
  final VoidCallback onClose;

  /// Null while the form is not ready to save.
  final VoidCallback? onSave;
  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final l = AppL10n.of(context);
    final message = error;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: s.xl, vertical: s.md),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l.close,
            visualDensity: VisualDensity.compact,
            icon: Icon(PhosphorIconsLight.arrowLeft, size: s.xl3),
            onPressed: onClose,
          ),
          SizedBox(width: s.md),
          ZenTaoKindIcon(kind),
          SizedBox(width: s.md),
          Text(
            title,
            style: context.typography.titleSm.copyWith(color: c.textPrimary),
          ),
          SizedBox(width: s.xl),
          Expanded(
            child: message == null
                ? const SizedBox.shrink()
                : Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.bodySm.copyWith(color: c.error),
                  ),
          ),
          SizedBox(width: s.xl),
          AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            onPressed: onClose,
            child: Text(l.cancel),
          ),
          SizedBox(width: s.md),
          AppButton.filled(
            size: AppButtonSize.small,
            onPressed: onSave,
            isLoading: saving,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: s.sm,
              children: [
                Icon(PhosphorIconsLight.floppyDisk, size: s.xl2),
                Text(l.save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
