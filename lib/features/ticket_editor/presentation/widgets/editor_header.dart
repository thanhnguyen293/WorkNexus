import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
      padding: EdgeInsets.symmetric(horizontal: s.xl3, vertical: s.lg),
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: context.hairlineSide),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l.close,
            icon: Icon(PhosphorIconsLight.arrowLeft, size: s.xl4),
            onPressed: onClose,
          ),
          SizedBox(width: s.md),
          ZenTaoKindIcon(kind, large: true),
          SizedBox(width: s.lg),
          Text(
            title,
            style: context.typography.title.copyWith(color: c.textPrimary),
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
          TextButton(onPressed: onClose, child: Text(l.cancel)),
          SizedBox(width: s.md),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? SizedBox.square(
                    dimension: s.xl2,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(PhosphorIconsLight.floppyDisk, size: s.xl3),
            label: Text(l.save),
          ),
        ],
      ),
    );
  }
}
