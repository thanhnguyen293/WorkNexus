import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/markdown_format.dart';
import 'chat_composer_controller.dart';
import 'chat_composer_input.dart';
import 'chat_composer_plain_input.dart';
import 'chat_composer_toolbar.dart';
import 'chat_markdown_toolbar.dart';

/// Rows the input starts with in Markdown mode, and holds when expanded.
const int _kMarkdownLines = 3;
const int _kExpandedLines = 14;

/// The input with its send button. Plain: one growing line of a plain text
/// field, send at its right. Markdown: a taller rich-text input over the
/// formatting toolbar, send at the toolbar's right.
class ChatComposerField extends StatefulWidget {
  const ChatComposerField({
    super.key,
    required this.controller,
    required this.focus,
    required this.autofocus,
    required this.markdown,
    required this.onSend,
    required this.onLike,
    this.onKey,
    this.hint,
  });

  final ChatComposerController controller;
  final FocusNode focus;
  final bool autofocus;
  final bool markdown;
  final VoidCallback onSend;
  final VoidCallback onLike;
  final ChatComposerKeyHandler? onKey;
  final String? hint;

  @override
  State<ChatComposerField> createState() => _ChatComposerFieldState();
}

class _ChatComposerFieldState extends State<ChatComposerField> {
  bool _expanded = false;

  /// Applies a toolbar format to the selection and goes back to typing.
  void _format(MarkdownFormat format) {
    widget.controller.apply(format);
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
              child: ChatComposerPlainInput(
                controller: widget.controller.plain,
                focus: widget.focus,
                autofocus: widget.autofocus,
                onKey: widget.onKey,
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
            autofocus: widget.autofocus,
            onKey: widget.onKey,
            hint: AppL10n.of(context).chatMarkdownHint(shortcut),
            minLines: lines,
            maxLines: _expanded ? _kExpandedLines : null,
          ),
          Row(
            children: [
              Expanded(
                child: ChatMarkdownToolbar(
                  controller: widget.controller,
                  onFormat: _format,
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
