import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/value_objects/emoji_shortnames.dart';
import '../providers/chat_providers.dart';
import '../providers/sticker_providers.dart';
import 'chat_sticker_grid.dart';

const int _kEmojiColumns = 8;
const int _kVisibleRows = 7;

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

/// Tabs: emoji to type, large emoji to send, the user's own stickers, then
/// one tab per bundled sticker set.
class ChatEmojiPanel extends ConsumerWidget {
  const ChatEmojiPanel({
    super.key,
    required this.thread,
    required this.onInsert,
    required this.onSent,
  });

  final ChatThreadKey thread;
  final ValueChanged<String> onInsert;

  /// Called as a sticker or large emoji is sent (closes the panel).
  final VoidCallback onSent;

  /// Closes the panel and sends; a failure is reported through the
  /// messenger captured first, as the panel's context is gone by then.
  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    Future<Result<void>> Function(StickerController c) send,
  ) async {
    final controller = ref.read(stickerControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppL10n.of(context);
    onSent();
    final result = await send(controller);
    if (result case Err(:final failure)) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l.chatActionFailed(failure.message))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final stickers = switch (ref.watch(chatStickersProvider)) {
      AsyncData(value: Ok(:final value)) => value,
      _ => const <ChatSticker>[],
    };
    final packs = <String, List<ChatSticker>>{};
    for (final sticker in stickers.where((s) => !s.custom)) {
      (packs[sticker.pack] ??= []).add(sticker);
    }
    final mine = [
      for (final s in stickers)
        if (s.custom) s,
    ];
    void sendSticker(ChatSticker sticker) =>
        _send(context, ref, (c) => c.send(thread, sticker));

    final tabs = <(String, Widget)>[
      (l.chatEmoji, _EmojiGrid(onPick: onInsert)),
      (
        l.chatStickersTab,
        _EmojiGrid(
          large: true,
          onPick: (e) => _send(context, ref, (c) => c.sendEmoji(thread, e)),
        ),
      ),
      (
        l.chatMyStickers,
        ChatStickerGrid(stickers: mine, editable: true, onPick: sendSticker),
      ),
      for (final MapEntry(:key, :value) in packs.entries)
        (key, ChatStickerGrid(stickers: value, onPick: sendSticker)),
    ];
    return SizedBox(
      width: s.xl6 * _kEmojiColumns + s.md * 2,
      height: s.xl6 * (_kVisibleRows + 1),
      child: DefaultTabController(
        // A new set changes the tab count.
        key: ValueKey(tabs.length),
        length: tabs.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: context.typography.bodySmStrong,
              unselectedLabelStyle: context.typography.bodySm,
              tabs: [for (final (label, _) in tabs) Tab(text: label)],
            ),
            Expanded(
              child: TabBarView(children: [for (final (_, view) in tabs) view]),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.onPick, this.large = false});

  final ValueChanged<String> onPick;

  /// Fewer, bigger cells: the large emoji sent as stickers.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final columns = large ? _kEmojiColumns ~/ 2 : _kEmojiColumns;
    final style = context.typography.titleLg.copyWith(height: 1);
    return GridView.builder(
      padding: EdgeInsets.all(s.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
      ),
      itemCount: _emoji.length,
      itemBuilder: (context, i) => InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(context.radii.md),
        onTap: () => onPick(_emoji[i]),
        child: Center(
          child: Text(
            _emoji[i],
            style: large ? style.copyWith(fontSize: s.xl6 * 0.9) : style,
          ),
        ),
      ),
    );
  }
}
