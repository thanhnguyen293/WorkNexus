import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

export 'editor_table_row.dart';

/// Renders an individual editable or read-only cell in an embedded editor table.
class TableCellWidget extends StatefulWidget {
  const TableCellWidget({
    super.key,
    required this.initialText,
    required this.isHeader,
    required this.readOnly,
    required this.isLastCol,
    required this.width,
    this.focusNode,
    this.onNextCell,
    this.onPreviousCell,
    this.quillController,
    required this.onChanged,
  });

  final String initialText;
  final bool isHeader;
  final bool readOnly;
  final bool isLastCol;
  final double width;
  final FocusNode? focusNode;
  final VoidCallback? onNextCell;
  final VoidCallback? onPreviousCell;
  final QuillController? quillController;
  final ValueChanged<String> onChanged;

  @override
  State<TableCellWidget> createState() => TableCellWidgetState();
}

String _sanitizeCellInput(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll(
      RegExp(
        r'[\uFFFC\uFFFD\uFEFF\u200B-\u200D\u0000-\u0008\u000B\u000C\u000E-\u001F]',
      ),
      '',
    );

class TableCellWidgetState extends State<TableCellWidget> {
  late final TextEditingController controller;
  late final UndoHistoryController undoController;
  FocusNode? _internalFocusNode;

  FocusNode get effectiveFocusNode =>
      widget.focusNode ??
      (_internalFocusNode ??= FocusNode(debugLabel: 'cell_internal'));

  @override
  void initState() {
    super.initState();
    final initial = _sanitizeCellInput(widget.initialText);
    controller = TextEditingController(text: initial);
    undoController = UndoHistoryController();
    effectiveFocusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TableCellWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)
          ?.removeListener(_onFocusChange);
      effectiveFocusNode.addListener(_onFocusChange);
    }
    final clean = _sanitizeCellInput(widget.initialText);
    if (!effectiveFocusNode.hasFocus &&
        widget.initialText != oldWidget.initialText &&
        clean != controller.text) {
      final oldSel = controller.selection;
      controller.text = clean;
      if (oldSel.isValid) {
        controller.selection = TextSelection.collapsed(
          offset: math.min(oldSel.extentOffset, clean.length),
        );
      }
    }
  }

  void _onFocusChange() {
    if (effectiveFocusNode.hasFocus) {
      widget.quillController?.skipRequestKeyboard = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    (widget.focusNode ?? _internalFocusNode)?.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    undoController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _handleDelete({required bool forward}) {
    final val = controller.value;
    if (!val.selection.isValid) return;
    if (!val.selection.isCollapsed) {
      final start = math.min(val.selection.start, val.selection.end);
      final end = math.max(val.selection.start, val.selection.end);
      final newText = val.text.replaceRange(start, end, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
      widget.onChanged(newText);
      return;
    }
    final offset = val.selection.extentOffset;
    if (!forward) {
      if (offset > 0) {
        final newText = val.text.replaceRange(offset - 1, offset, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: offset - 1),
        );
        widget.onChanged(newText);
      }
    } else {
      if (offset < val.text.length) {
        final newText = val.text.replaceRange(offset, offset + 1, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: offset),
        );
        widget.onChanged(newText);
      }
    }
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.isEmpty) return;
    final text = _sanitizeCellInput(raw);
    if (text.isEmpty) return;

    final val = controller.value;
    final start =
        val.selection.start < 0 ? val.text.length : val.selection.start;
    final end = val.selection.end < 0 ? val.text.length : val.selection.end;
    final min = math.min(start, end);
    final max = math.max(start, end);
    final newText = val.text.replaceRange(min, max, text);
    final newOffset = min + text.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    widget.onChanged(newText);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    final hasFocus = !widget.readOnly && effectiveFocusNode.hasFocus;
    final textStyle = (widget.isHeader
            ? context.typography.bodyStrong.copyWith(
                fontWeight: FontWeight.w600,
              )
            : context.typography.body)
        .copyWith(color: c.textPrimary, fontSize: 13);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        widget.quillController?.skipRequestKeyboard = true;
      },
      child: MouseRegion(
        cursor: widget.readOnly
            ? SystemMouseCursors.basic
            : SystemMouseCursors.text,
        child: Container(
          width: widget.width,
          constraints: const BoxConstraints(minHeight: 34),
          decoration: BoxDecoration(
            color: hasFocus ? c.accent.withValues(alpha: 0.08) : null,
            border: widget.isLastCol
                ? null
                : Border(right: BorderSide(color: c.border)),
          ),
          child: widget.readOnly
              ? Padding(
                  padding: EdgeInsets.symmetric(horizontal: s.xs, vertical: 7),
                  child: Text(widget.initialText, style: textStyle),
                )
              : Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.keyA, control: true):
                        SelectAllTextIntent(SelectionChangedCause.keyboard),
                    SingleActivator(LogicalKeyboardKey.keyA, meta: true):
                        SelectAllTextIntent(SelectionChangedCause.keyboard),
                    SingleActivator(LogicalKeyboardKey.backspace):
                        DeleteCharacterIntent(forward: false),
                    SingleActivator(LogicalKeyboardKey.delete):
                        DeleteCharacterIntent(forward: true),
                  },
                  child: Actions(
                    actions: {
                      SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
                        onInvoke: (_) {
                          controller.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: controller.text.length,
                          );
                          return null;
                        },
                      ),
                      DeleteCharacterIntent:
                          CallbackAction<DeleteCharacterIntent>(
                        onInvoke: (intent) {
                          _handleDelete(forward: intent.forward);
                          return null;
                        },
                      ),
                      PasteTextIntent: CallbackAction<PasteTextIntent>(
                        onInvoke: (_) => _handlePaste(),
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
                    },
                    child: TextFormField(
                      controller: controller,
                      undoController: undoController,
                      focusNode: effectiveFocusNode,
                      style: textStyle,
                      maxLines: null,
                      minLines: 1,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: s.xs,
                          vertical: 7,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(
                            r'[\uFFFC\uFFFD\uFEFF\u200B-\u200D\u0000-\u0008\u000B\u000C\u000E-\u001F]',
                          ),
                        ),
                      ],
                      onChanged: widget.onChanged,
                      onTap: () {
                        widget.quillController?.skipRequestKeyboard = true;
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
