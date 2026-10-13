import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'chat_composer_input.dart';
import 'chat_editor_styles.dart';
import 'chat_mention_text_controller.dart';

/// The composer's borderless, growing message field with Markdown off: a
/// plain [TextField], so typing goes through the platform's text input
/// untouched — what IMEs such as Unikey are built for.
class ChatComposerPlainInput extends StatelessWidget {
  const ChatComposerPlainInput({
    super.key,
    required this.controller,
    required this.focus,
    required this.autofocus,
    this.onKey,
    this.hint,
  });

  final ChatMentionTextController controller;
  final FocusNode focus;
  final bool autofocus;
  final ChatComposerKeyHandler? onKey;

  /// Replaces the default "Message — Enter to send" hint.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final body = chatEditorBodyStyle(context);
    final onKey = this.onKey;
    // Sees the field's keys before the text-editing shortcuts above it do.
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: onKey == null
          ? null
          : (_, event) => onKey(event) ?? KeyEventResult.ignored,
      child: TextField(
        controller: controller,
        focusNode: focus,
        autofocus: autofocus,
        minLines: 1,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        style: body,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint ?? AppL10n.of(context).chatComposerHint,
          hintStyle: body.copyWith(color: context.colors.textTertiary),
          contentPadding: EdgeInsets.symmetric(vertical: context.spacing.lg),
        ),
      ),
    );
  }
}
