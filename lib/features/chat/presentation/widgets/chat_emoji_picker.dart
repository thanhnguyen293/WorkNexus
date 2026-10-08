import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_emoji_panel.dart';

/// Tool-row button opening the emoji and sticker panel. Emoji are inserted
/// at the cursor (the panel stays open for more); a sticker or large emoji
/// is sent at once and closes it.
class ChatEmojiButton extends StatefulWidget {
  const ChatEmojiButton({
    super.key,
    required this.thread,
    required this.text,
    required this.focus,
  });

  final ChatThreadKey thread;
  final TextEditingController text;
  final FocusNode focus;

  @override
  State<ChatEmojiButton> createState() => _ChatEmojiButtonState();
}

class _ChatEmojiButtonState extends State<ChatEmojiButton> {
  final _menu = MenuController();

  void _insert(String emoji) {
    final value = widget.text.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    widget.text.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.spacing;
    return MenuAnchor(
      controller: _menu,
      // Back to typing once the panel closes.
      onClose: widget.focus.requestFocus,
      alignmentOffset: Offset(0, -s.xs),
      menuChildren: [
        ChatEmojiPanel(
          thread: widget.thread,
          onInsert: _insert,
          onSent: _menu.close,
        ),
      ],
      builder: (context, menu, _) => IconButton(
        tooltip: AppL10n.of(context).chatEmoji,
        isSelected: menu.isOpen,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        iconSize: s.xl5,
        style: IconButton.styleFrom(
          backgroundColor: menu.isOpen ? c.selectionFill : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radii.md),
          ),
        ),
        icon: Icon(
          PhosphorIconsLight.smiley,
          color: menu.isOpen ? c.accent : c.textSecondary,
        ),
      ),
    );
  }
}
