// Quill's key handler and Markdown typing shortcuts are marked experimental.
// ignore_for_file: experimental_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_composer_controller.dart';
import 'chat_editor_styles.dart';
import 'chat_mention_embed.dart';

/// Handles a key before the editor does; null lets the editor have it.
typedef ChatComposerKeyHandler = KeyEventResult? Function(KeyEvent event);

/// The composer's borderless, growing rich-text field (Markdown on):
/// Markdown typed by hand turns into formatting as it is typed (`**bold**`,
/// `- ` lists, `# ` headings…).
class ChatComposerInput extends StatefulWidget {
  const ChatComposerInput({
    super.key,
    required this.controller,
    required this.focus,
    required this.autofocus,
    this.onKey,
    this.hint,
    this.minLines = 1,
    this.maxLines,
  });

  final ChatComposerController controller;
  final FocusNode focus;
  final bool autofocus;
  final ChatComposerKeyHandler? onKey;

  /// Rows shown empty, and at most before it scrolls (default 10).
  final int minLines;
  final int? maxLines;

  /// Replaces the default "Message — Enter to send" hint.
  final String? hint;

  @override
  State<ChatComposerInput> createState() => _ChatComposerInputState();
}

class _ChatComposerInputState extends State<ChatComposerInput> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult? _key(KeyEvent event, Node? _) {
    if (widget.onKey?.call(event) case final result?) return result;
    final keys = HardwareKeyboard.instance;
    if (!keys.isControlPressed && !keys.isMetaPressed) return null;
    final key = event.logicalKey;
    // The editor's search and image dialogs have no place in a message.
    if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.keyG) {
      return KeyEventResult.handled;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final line = chatEditorBodyStyle(context).fontSize! * kChatEditorLineHeight;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
      child: QuillEditor(
        controller: widget.controller.quill,
        focusNode: widget.focus,
        scrollController: _scroll,
        config: QuillEditorConfig(
          autoFocus: widget.autofocus,
          placeholder: widget.hint ?? AppL10n.of(context).chatComposerHint,
          minHeight: line * widget.minLines,
          maxHeight: line * (widget.maxLines ?? 10),
          customStyles: chatEditorStyles(context),
          embedBuilders: const [ChatMentionEmbedBuilder()],
          onKeyPressed: _key,
          characterShortcutEvents: standardCharactersShortcutEvents,
          spaceShortcutEvents: standardSpaceShorcutEvents,
        ),
      ),
    );
  }
}
