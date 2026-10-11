import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/usecases/apply_markdown_format.dart';
import '../../domain/value_objects/markdown_format.dart';
import 'chat_composer_input.dart';
import 'chat_composer_toolbar.dart';
import 'chat_markdown_toolbar.dart';

/// Rows the input starts with in Markdown mode, and holds when expanded.
const int _kMarkdownLines = 3;
const int _kExpandedLines = 14;

/// The input with its send button. Plain: one growing line, send at its
/// right. Markdown: a taller input over the formatting toolbar, send at
/// the toolbar's right.
class ChatComposerField extends StatefulWidget {
  const ChatComposerField({
    super.key,
    required this.controller,
    required this.focus,
    required this.undo,
    required this.autofocus,
    required this.markdown,
    required this.onSend,
    required this.onLike,
    this.hint,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final UndoHistoryController undo;
  final bool autofocus;
  final bool markdown;
  final VoidCallback onSend;
  final VoidCallback onLike;
  final String? hint;

  @override
  State<ChatComposerField> createState() => _ChatComposerFieldState();
}

class _ChatComposerFieldState extends State<ChatComposerField> {
  bool _expanded = false;

  /// Applies a Markdown toolbar format to the selection (the caret, or the
  /// end of the text when there is none).
  void _format(MarkdownFormat format) {
    final value = widget.controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final edit = const ApplyMarkdownFormat()((
      text: value.text,
      start: selection.start,
      end: selection.end,
    ), format);
    widget.controller.value = TextEditingValue(
      text: edit.text,
      selection: TextSelection(baseOffset: edit.start, extentOffset: edit.end),
    );
    widget.focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final send = ChatComposerSendButton(
      text: widget.controller,
      onSend: widget.onSend,
      onLike: widget.onLike,
    );
    if (!widget.markdown) {
      return Padding(
        padding: EdgeInsets.fromLTRB(s.xl3, s.sm, s.lg, s.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ChatComposerInput(
                controller: widget.controller,
                focus: widget.focus,
                undo: widget.undo,
                autofocus: widget.autofocus,
                hint: widget.hint,
              ),
            ),
            SizedBox(width: s.md),
            send,
          ],
        ),
      );
    }
    final shortcut = defaultTargetPlatform == TargetPlatform.macOS
        ? 'Cmd + Shift + X'
        : 'Ctrl + Shift + X';
    final lines = _expanded ? _kExpandedLines : _kMarkdownLines;
    return Padding(
      padding: EdgeInsets.fromLTRB(s.xl3, s.sm, s.lg, s.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChatComposerInput(
            controller: widget.controller,
            focus: widget.focus,
            undo: widget.undo,
            autofocus: widget.autofocus,
            hint: AppL10n.of(context).chatMarkdownHint(shortcut),
            minLines: lines,
            maxLines: _expanded ? _kExpandedLines : null,
          ),
          Row(
            children: [
              Expanded(
                child: ChatMarkdownToolbar(
                  onFormat: _format,
                  undo: widget.undo,
                  expanded: _expanded,
                  onToggleExpanded: () =>
                      setState(() => _expanded = !_expanded),
                ),
              ),
              SizedBox(width: s.md),
              send,
            ],
          ),
        ],
      ),
    );
  }
}
