import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import 'chat_emoji_panel.dart';
import 'chat_side_panel_frame.dart';

/// The emoji and sticker picker expanded beside the chat: full height, and
/// it stays open as stickers are sent. Emoji go to the chat's composer (see
/// [chatEmojiInsertProvider]). Collapsing (its header button or Esc) closes
/// it and turns the picker back into a popup.
class ChatEmojiSidePanel extends ConsumerWidget {
  const ChatEmojiSidePanel({super.key, required this.thread});

  final ChatThreadKey thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return ChatSidePanelFrame(
      title: l.chatEmojiPanelTitle,
      closeIcon: LucideIcons.minimize2300,
      closeTooltip: l.chatEmojiCollapse,
      onClose: () {
        ref.read(chatEmojiDockedProvider.notifier).state = false;
        ref.read(chatSidePanelProvider(thread).notifier).state = null;
      },
      // On the header's colour, not the window's, so it reads as a panel;
      // its tabs as tall as the pinned-message bar beside it.
      child: ColoredBox(
        color: context.colors.surface,
        child: ChatEmojiTabs(
          thread: thread,
          tabRowHeight: kChatSubHeaderHeight,
          onInsert: (emoji) {
            ref.read(chatEmojiInsertProvider(thread).notifier)
              ..state = null
              ..state = emoji;
          },
          onSent: () {},
        ),
      ),
    );
  }
}
