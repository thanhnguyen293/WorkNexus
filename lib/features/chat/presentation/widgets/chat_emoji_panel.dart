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
import 'chat_sticker_panel.dart';

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

/// Two tabs: stickers (every set, switched from the bar at the bottom) and
/// emoji to type — an emoji sent on its own shows large.
class ChatEmojiPanel extends ConsumerWidget {
  const ChatEmojiPanel({
    super.key,
    required this.thread,
    required this.onInsert,
    required this.onSent,
  });

  final ChatThreadKey thread;
  final ValueChanged<String> onInsert;

  /// Called as a sticker is sent (closes the panel).
  final VoidCallback onSent;

  /// Closes the panel and sends; a failure is reported through the
  /// messenger captured first, as the panel's context is gone by then.
  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    ChatSticker sticker,
  ) async {
    final controller = ref.read(stickerControllerProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = AppL10n.of(context);
    onSent();
    final result = await controller.send(thread, sticker);
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
    return SizedBox(
      width: s.xl6 * _kEmojiColumns + s.md * 2,
      height: s.xl6 * (_kVisibleRows + 2),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              labelStyle: context.typography.bodySmStrong,
              unselectedLabelStyle: context.typography.bodySm,
              tabs: [
                Tab(text: l.chatStickersTab),
                Tab(text: l.chatEmoji),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ChatStickerPanel(
                    stickers: stickers,
                    onPick: (sticker) => _send(context, ref, sticker),
                  ),
                  _EmojiGrid(onPick: onInsert),
                ],
              ),
            ),
          ],
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
    final style = context.typography.titleLg.copyWith(height: 1);
    return GridView.builder(
      padding: EdgeInsets.all(s.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kEmojiColumns,
      ),
      itemCount: _emoji.length,
      itemBuilder: (context, i) => InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(context.radii.md),
        onTap: () => onPick(_emoji[i]),
        child: Center(child: Text(_emoji[i], style: style)),
      ),
    );
  }
}
