import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/zentao_kind_icon.dart';
import '../../../../l10n/app_localizations.dart';

/// The editor's bar: back, what is being edited (and whether its draft is
/// kept), why the last save failed, then the actions at the right edge.
class EditorHeader extends StatelessWidget {
  const EditorHeader({
    super.key,
    required this.title,
    required this.kind,
    required this.onClose,
    this.onSave,
    this.saving = false,
    this.error,
    this.draftSaved = false,
    this.draftPicker,
    this.onDiscardDraft,
  });

  final String title;

  /// The ZenTao kind being edited (`bug`, `task`), shown as its icon.
  final String kind;
  final VoidCallback onClose;

  /// Null while the form is not ready to save.
  final VoidCallback? onSave;
  final bool saving;
  final String? error;

  /// A new ticket's draft is kept on this device.
  final bool draftSaved;

  /// Picks another kept draft, beside the title; null for none.
  final Widget? draftPicker;

  /// Deletes the kept draft; null hides the action.
  final VoidCallback? onDiscardDraft;

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
          AppIconButton(
            icon: LucideIcons.arrowLeft300,
            tooltip: l.ticketEditorBack,
            onPressed: onClose,
          ),
          SizedBox(width: s.md),
          ZenTaoKindIcon(kind),
          SizedBox(width: s.md),
          // Takes the free width, so the actions sit at the bar's right edge.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.titleSm.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (draftSaved) ...[
                  SizedBox(width: s.lg),
                  const _DraftSavedNote(),
                ],
                if (draftPicker case final picker?) ...[
                  SizedBox(width: s.lg),
                  picker,
                ],
              ],
            ),
          ),
          if (message != null) ...[
            SizedBox(width: s.xl),
            Flexible(
              child: Tooltip(
                message: message,
                child: Text(
                  l.ticketEditorSaveFailed(message),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.typography.bodySm.copyWith(color: c.error),
                ),
              ),
            ),
          ],
          SizedBox(width: s.xl),
          if (onDiscardDraft case final discard?) ...[
            AppButton.textNeutral(
              size: AppButtonSize.small,
              icon: LucideIcons.trash2300,
              onPressed: discard,
              child: Text(l.ticketDraftDiscard),
            ),
            SizedBox(width: s.md),
          ],
          AppButton.outlinedNeutral(
            size: AppButtonSize.small,
            onPressed: onClose,
            child: Text(l.cancel),
          ),
          SizedBox(width: s.md),
          AppButton.filled(
            size: AppButtonSize.small,
            icon: LucideIcons.save300,
            onPressed: onSave,
            isLoading: saving,
            child: Text(l.save),
          ),
        ],
      ),
    );
  }
}

/// "Draft saved", explaining what is kept on hover.
class _DraftSavedNote extends StatelessWidget {
  const _DraftSavedNote();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    return Tooltip(
      message: l.ticketDraftSavedHint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.cloudCheck300,
            size: context.sizes.iconSm,
            color: c.textTertiary,
          ),
          SizedBox(width: context.spacing.xs),
          Text(
            l.ticketDraftSaved,
            style: context.typography.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}
