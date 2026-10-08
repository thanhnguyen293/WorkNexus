import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/value_objects/emoji_shortnames.dart';

const int _kColumns = 8;
const int _kVisibleRows = 6;

/// The emoji offered: those the server keeps (sent as Emojione shortnames,
/// which the official client also renders), in the shortname list's order.
/// Older symbols (❤ ✌) get the emoji variation selector, or macOS draws
/// them as plain text glyphs.
final List<String> _emoji = [
  for (final rune in kEmojiShortnames.values)
    rune > 0xFFFF
        ? String.fromCharCode(rune)
        : '${String.fromCharCode(rune)}\u{FE0F}',
];

/// Tool-row button opening an emoji grid; a pick is inserted at the cursor
/// and the grid stays open for more.
class ChatEmojiButton extends StatefulWidget {
  const ChatEmojiButton({super.key, required this.text, required this.focus});

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
      // Back to typing once the grid closes.
      onClose: widget.focus.requestFocus,
      alignmentOffset: Offset(0, -s.xs),
      menuChildren: [_EmojiGrid(onPick: _insert)],
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
          Icons.emoji_emotions_outlined,
          color: menu.isOpen ? c.accent : c.textSecondary,
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final cell = s.xl6;
    return SizedBox(
      width: cell * _kColumns + s.md * 2,
      height: cell * _kVisibleRows + s.md * 2,
      child: GridView.builder(
        padding: EdgeInsets.all(s.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _kColumns,
          mainAxisExtent: cell,
        ),
        itemCount: _emoji.length,
        itemBuilder: (context, i) => InkWell(
          borderRadius: BorderRadius.circular(context.radii.md),
          onTap: () => onPick(_emoji[i]),
          child: Center(
            child: Text(
              _emoji[i],
              style: context.typography.titleLg.copyWith(height: 1),
            ),
          ),
        ),
      ),
    );
  }
}
