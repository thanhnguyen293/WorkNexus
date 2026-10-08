import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_layout.dart';
import '../widgets/chat_notification_banner.dart';
import '../widgets/chat_status_banner.dart';
import '../widgets/conversation_list_pane.dart';
import '../widgets/thread_pane.dart';

/// The ZenTao chat view: connection banner, chat list and the open thread.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final accountId = ref.watch(selectedChatAccountIdProvider);
    if (accountId == null) {
      return Center(child: AppInlineNote(text: l.chatNoZentaoAccount));
    }
    final chatGid = ref.watch(selectedChatGidProvider(accountId));
    final thread = chatGid == null
        ? null
        : (accountId: accountId, chatGid: chatGid);
    // A panel the user opened stays even when the info panel has no room.
    final panelOpen =
        thread != null &&
        (ref.watch(openReplyThreadProvider(thread)) != null ||
            ref.watch(chatSidePanelProvider(thread)) != null);
    return ColoredBox(
      color: context.colors.background,
      child: Column(
        children: [
          ChatStatusBanner(accountId: accountId),
          const ChatNotificationBanner(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = ChatLayout.of(
                  constraints.maxWidth,
                  panelOpen: panelOpen,
                );
                return ChatLayoutScope(
                  layout: layout,
                  child: Row(
                    children: [
                      SizedBox(
                        width: layout.compactList
                            ? kChatListCompactWidth
                            : kChatListWidth,
                        child: ConversationListPane(
                          accountId: accountId,
                          compact: layout.compactList,
                        ),
                      ),
                      Expanded(
                        child: chatGid == null
                            ? Center(
                                child: AppInlineNote(
                                  text: l.chatSelectConversation,
                                ),
                              )
                            : ThreadPane(
                                key: ValueKey('$accountId/$chatGid'),
                                thread: thread!,
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
