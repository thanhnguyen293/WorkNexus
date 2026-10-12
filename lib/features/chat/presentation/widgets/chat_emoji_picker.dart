import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_context_menu.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_composer_toolbar.dart';
import 'chat_emoji_panel.dart';
import 'chat_layout.dart';
import 'chat_panels.dart';

/// Tool-row button opening the emoji and sticker panel. Emoji are inserted
/// at the cursor (the panel stays open for more); a sticker or large emoji
/// is sent at once and closes it.
///
/// In the chat's own composer ([dockable]) the popup can expand into a panel
/// beside the chat; from then on this button shows and hides that panel
/// until it is collapsed again.
class ChatEmojiButton extends ConsumerStatefulWidget {
  const ChatEmojiButton({
    super.key,
    required this.thread,
    required this.text,
    required this.focus,
    this.dockable = false,
  });

  final ChatThreadKey thread;
  final TextEditingController text;
  final FocusNode focus;
  final bool dockable;

  @override
  ConsumerState<ChatEmojiButton> createState() => _ChatEmojiButtonState();
}

class _ChatEmojiButtonState extends ConsumerState<ChatEmojiButton> {
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

  /// Shows or hides the expanded panel beside the chat.
  void _toggleDocked() => toggleChatSidePanel(
    ref,
    widget.thread,
    ChatSidePanel.emoji,
    infoRoom: ChatLayoutScope.of(context).infoRoom,
  );

  void _expand() {
    _menu.close();
    ref.read(chatEmojiDockedProvider.notifier).state = true;
    _toggleDocked();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final dockable = widget.dockable;
    if (dockable) {
      ref.listen(chatEmojiInsertProvider(widget.thread), (_, emoji) {
        if (emoji == null) return;
        _insert(emoji);
        widget.focus.requestFocus();
      });
    }
    final docked = dockable && ref.watch(chatEmojiDockedProvider);
    final dockedOpen =
        docked &&
        ref.watch(chatSidePanelProvider(widget.thread)) == ChatSidePanel.emoji;
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
          onExpand: dockable ? _expand : null,
        ),
      ],
      builder: (context, menu, _) => ChatComposerToolButton(
        icon: LucideIcons.smile300,
        tooltip: AppL10n.of(context).chatEmoji,
        selected: docked ? dockedOpen : menu.isOpen,
        onPressed: docked
            ? _toggleDocked
            : () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
