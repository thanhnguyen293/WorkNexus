import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An action that delegates to the calling [Action.overridable] default action
/// from [EditableText], preventing ancestor [QuillEditor] overrides from
/// intercepting caret navigation, selection, or clipboard events in table cells.
class CellPassThroughAction<T extends Intent> extends Action<T> {
  @override
  Object? invoke(T intent) {
    return callingAction?.invoke(intent);
  }

  @override
  bool isEnabled(T intent) {
    return callingAction?.isEnabled(intent) ?? true;
  }

  @override
  bool consumesKey(T intent) {
    return callingAction?.consumesKey(intent) ?? true;
  }
}

/// Standard keyboard shortcuts bound directly inside a table cell text field.
const Map<ShortcutActivator, Intent> cellKeyboardShortcuts = {
  SingleActivator(LogicalKeyboardKey.keyA, control: true): SelectAllTextIntent(
    SelectionChangedCause.keyboard,
  ),
  SingleActivator(LogicalKeyboardKey.keyA, meta: true): SelectAllTextIntent(
    SelectionChangedCause.keyboard,
  ),
  SingleActivator(LogicalKeyboardKey.backspace): DeleteCharacterIntent(
    forward: false,
  ),
  SingleActivator(LogicalKeyboardKey.delete): DeleteCharacterIntent(
    forward: true,
  ),
};

/// Builds the actions map for a table cell, combining cell-local editing actions
/// with pass-through actions that delegate caret navigation and selection to
/// Flutter's native [EditableText] handlers instead of ancestor Quill overrides.
Map<Type, Action<Intent>> buildCellActions({
  required TextEditingController controller,
  required UndoHistoryController undoController,
  required ValueChanged<String> onChanged,
  required void Function({required bool forward}) onDelete,
  required Future<void> Function() onPaste,
}) {
  return {
    SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
      onInvoke: (_) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
        return null;
      },
    ),
    DeleteCharacterIntent: CallbackAction<DeleteCharacterIntent>(
      onInvoke: (intent) {
        onDelete(forward: intent.forward);
        return null;
      },
    ),
    PasteTextIntent: CallbackAction<PasteTextIntent>(
      onInvoke: (_) => onPaste(),
    ),
    UndoTextIntent: CallbackAction<UndoTextIntent>(
      onInvoke: (_) {
        undoController.undo();
        return null;
      },
    ),
    RedoTextIntent: CallbackAction<RedoTextIntent>(
      onInvoke: (_) {
        undoController.redo();
        return null;
      },
    ),
    // Caret navigation and selection pass-throughs to protect cell content
    ExtendSelectionByCharacterIntent:
        CellPassThroughAction<ExtendSelectionByCharacterIntent>(),
    ExtendSelectionToNextWordBoundaryIntent:
        CellPassThroughAction<ExtendSelectionToNextWordBoundaryIntent>(),
    ExtendSelectionToLineBreakIntent:
        CellPassThroughAction<ExtendSelectionToLineBreakIntent>(),
    ExtendSelectionVerticallyToAdjacentLineIntent:
        CellPassThroughAction<ExtendSelectionVerticallyToAdjacentLineIntent>(),
    ExtendSelectionVerticallyToAdjacentPageIntent:
        CellPassThroughAction<ExtendSelectionVerticallyToAdjacentPageIntent>(),
    ExtendSelectionToDocumentBoundaryIntent:
        CellPassThroughAction<ExtendSelectionToDocumentBoundaryIntent>(),
    ExtendSelectionToNextParagraphBoundaryIntent:
        CellPassThroughAction<ExtendSelectionToNextParagraphBoundaryIntent>(),
    ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent:
        CellPassThroughAction<
          ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent
        >(),
    ExtendSelectionToNextWordBoundaryOrCaretLocationIntent:
        CellPassThroughAction<
          ExtendSelectionToNextWordBoundaryOrCaretLocationIntent
        >(),
    ExpandSelectionToLineBreakIntent:
        CellPassThroughAction<ExpandSelectionToLineBreakIntent>(),
    ExpandSelectionToDocumentBoundaryIntent:
        CellPassThroughAction<ExpandSelectionToDocumentBoundaryIntent>(),
    ScrollToDocumentBoundaryIntent:
        CellPassThroughAction<ScrollToDocumentBoundaryIntent>(),
    DeleteToNextWordBoundaryIntent:
        CellPassThroughAction<DeleteToNextWordBoundaryIntent>(),
    DeleteToLineBreakIntent: CellPassThroughAction<DeleteToLineBreakIntent>(),
    CopySelectionTextIntent: CellPassThroughAction<CopySelectionTextIntent>(),
  };
}
