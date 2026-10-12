import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_toolbar.dart';
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
    final s = context.spacing;
    return MenuAnchor(
      controller: _menu,
      // Back to typing once the panel closes.
      onClose: widget.focus.requestFocus,
      alignmentOffset: Offset(0, -s.xs),
      // The panel draws the app's popup card itself.
      style: appMenuAnchorStyle,
      menuChildren: [
        ChatEmojiPanel(
          thread: widget.thread,
          onInsert: _insert,
          onSent: _menu.close,
        ),
      ],
      builder: (context, menu, _) => ChatComposerToolButton(
        icon: LucideIcons.smile300,
        tooltip: AppL10n.of(context).chatEmoji,
        selected: menu.isOpen,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
