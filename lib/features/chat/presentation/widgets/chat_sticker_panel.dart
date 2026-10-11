import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/chat_sticker.dart';
import 'chat_sticker_grid.dart';
import 'chat_sticker_pack_bar.dart';

/// The sticker tab: one set's grid at a time, picked from the pack bar
/// below. Opens on the user's own stickers, or the first bundled set while
/// they have none.
class ChatStickerPanel extends ConsumerStatefulWidget {
  const ChatStickerPanel({
    super.key,
    required this.stickers,
    required this.onPick,
  });

  /// Every sticker: bundled sets and the user's own.
  final List<ChatSticker> stickers;
  final ValueChanged<ChatSticker> onPick;

  @override
  ConsumerState<ChatStickerPanel> createState() => _ChatStickerPanelState();
}

class _ChatStickerPanelState extends ConsumerState<ChatStickerPanel> {
  /// The set shown; '' is the user's own. Null until the user picks one.
  String? _pack;

  Future<void> _add() async {
    setState(() => _pack = '');
    await addStickersFromImages(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final mine = <ChatSticker>[];
    final bundled = <String, List<ChatSticker>>{};
    for (final sticker in widget.stickers) {
      if (sticker.custom) {
        mine.add(sticker);
      } else {
        (bundled[sticker.pack] ??= []).add(sticker);
      }
    }
    final pack =
        _pack ?? (mine.isEmpty && bundled.isNotEmpty ? bundled.keys.first : '');
    final shown = pack.isEmpty ? mine : bundled[pack] ?? const <ChatSticker>[];
    return Column(
      children: [
        Expanded(
          child: ChatStickerGrid(
            key: ValueKey(pack),
            stickers: shown,
            editable: pack.isEmpty,
            onPick: widget.onPick,
          ),
        ),
        Divider(height: 1, thickness: 1, color: context.colors.border),
        ChatStickerPackBar(
          packs: [
            (pack: '', cover: null),
            for (final MapEntry(:key, :value) in bundled.entries)
              (pack: key, cover: value.first),
          ],
          selected: pack,
          onSelect: (p) => setState(() => _pack = p),
          onAdd: _add,
        ),
      ],
    );
  }
}
