import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_borders.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_popup_card.dart';
import '../../../../core/widgets/app_state_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/chat_sticker.dart';
import '../../domain/value_objects/emoji_shortnames.dart';
import '../providers/chat_providers.dart';
import '../providers/sticker_providers.dart';
import 'chat_snack.dart';
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

/// The emoji and sticker picker as a popup over the composer, sized for
/// [_kEmojiColumns] emoji across. [onExpand], when given, adds a button that
/// moves it beside the chat instead.
class ChatEmojiPanel extends StatelessWidget {
  const ChatEmojiPanel({
    super.key,
    required this.thread,
    required this.onInsert,
    required this.onSent,
    this.onExpand,
  });

  final ChatThreadKey thread;
  final ValueChanged<String> onInsert;

  /// Called as a sticker is sent (closes the panel).
  final VoidCallback onSent;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final s = context.spacing;
    final expand = onExpand;
    return AppPopupCard(
      child: SizedBox(
        width: s.xl6 * _kEmojiColumns + s.md * 2,
        height: s.xl6 * (_kVisibleRows + 2),
        child: ChatEmojiTabs(
          thread: thread,
          onInsert: onInsert,
          onSent: onSent,
          action: expand == null
              ? null
              : AppIconButton(
                  icon: LucideIcons.maximize2300,
                  tooltip: AppL10n.of(context).chatEmojiExpand,
                  onPressed: expand,
                ),
        ),
      ),
    );
  }
}

/// Two tabs: stickers (every set, switched from the bar at the bottom) and
/// emoji to type — an emoji sent on its own shows large. Fills its box; the
/// popup and the expanded panel each give it one. [action] sits at the end
/// of the tab row; [tabRowHeight], when given, is the tab row's height with
/// its bottom border.
class ChatEmojiTabs extends ConsumerWidget {
  const ChatEmojiTabs({
    super.key,
    required this.thread,
    required this.onInsert,
    required this.onSent,
    this.action,
    this.tabRowHeight,
  });

  final ChatThreadKey thread;
  final ValueChanged<String> onInsert;

  /// Called as a sticker is sent.
  final VoidCallback onSent;
  final Widget? action;
  final double? tabRowHeight;

  /// Sends after [onSent] (which may close the popup); a failure is reported
  /// from the navigator's context, captured first, as the panel's own context
  /// may be gone by then.
  Future<void> _send(
    BuildContext context,
    WidgetRef ref,
    ChatSticker sticker,
  ) async {
    final controller = ref.read(stickerControllerProvider);
    final host = Navigator.of(context).context;
    onSent();
    final result = await controller.send(thread, sticker);
    if (result case Err(:final failure) when host.mounted) {
      showChatFailure(host, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final s = context.spacing;
    final c = context.colors;
    final stickerTab = switch (ref.watch(chatStickersProvider)) {
      AsyncData(value: Ok(:final value)) => ChatStickerPanel(
        stickers: value,
        onPick: (sticker) => _send(context, ref, sticker),
      ),
      AsyncData() || AsyncError() => AppStateView.error(
        compact: true,
        onRetry: () => ref.invalidate(chatStickersProvider),
      ),
      _ => const AppStateView.loading(compact: true),
    };
    // The tabs are as tall as the app's other tab rows, not Material's 46.
    final rowHeight = tabRowHeight;
    final tabHeight = rowHeight == null
        ? context.sizes.controlMd + s.md
        : rowHeight - context.borders.hairline;
    final action = this.action;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: context.hairlineSide),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    labelStyle: context.typography.bodySmStrong,
                    unselectedLabelStyle: context.typography.bodySm,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(height: tabHeight, text: l.chatStickersTab),
                      Tab(height: tabHeight, text: l.chatEmoji),
                    ],
                  ),
                ),
                if (action != null) ...[
                  VerticalDivider(width: 1, color: c.border),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: s.xs),
                    child: action,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                stickerTab,
                _EmojiGrid(onPick: onInsert),
              ],
            ),
          ),
        ],
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
