import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/inline_status.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_status_banner.dart';
import '../widgets/conversation_list_pane.dart';
import '../widgets/thread_pane.dart';

/// Width of the chat list column.
const double _kChatListWidth = 320;

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
    return ColoredBox(
      color: context.colors.background,
      child: Column(
        children: [
          ChatStatusBanner(accountId: accountId),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: _kChatListWidth,
                  child: ConversationListPane(accountId: accountId),
                ),
                Expanded(
                  child: chatGid == null
                      ? Center(
                          child: AppInlineNote(text: l.chatSelectConversation),
                        )
                      : ThreadPane(
                          key: ValueKey('$accountId/$chatGid'),
                          thread: (accountId: accountId, chatGid: chatGid),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
