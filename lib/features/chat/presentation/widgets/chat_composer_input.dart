import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';

/// The composer's borderless, growing message field.
class ChatComposerInput extends StatelessWidget {
  const ChatComposerInput({
    super.key,
    required this.controller,
    required this.focus,
    required this.autofocus,
    this.undo,
    this.hint,
    this.minLines = 1,
    this.maxLines,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool autofocus;
  final UndoHistoryController? undo;

  /// Rows shown empty, and at most before it scrolls (default 10).
  final int minLines;
  final int? maxLines;

  /// Replaces the default "Message — Enter to send" hint.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextField(
      controller: controller,
      focusNode: focus,
      autofocus: autofocus,
      undoController: undo,
      minLines: minLines,
      maxLines: maxLines ?? 10,
      keyboardType: TextInputType.multiline,
      style: context.typography.body.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint ?? AppL10n.of(context).chatComposerHint,
        hintStyle: context.typography.body.copyWith(color: c.textTertiary),
        contentPadding: EdgeInsets.symmetric(vertical: context.spacing.lg),
      ),
    );
  }
}
