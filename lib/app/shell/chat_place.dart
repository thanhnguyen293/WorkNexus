import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_sizes.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/providers/chat_providers.dart';
import '../../features/chat/presentation/widgets/chat_layout.dart';
import '../../features/chat/presentation/widgets/conversation_list_pane.dart';
import '../../shared/shell_pane/tool_pane_scaffold.dart';

/// The chat's column beside the rail: its conversations. In a window too
/// narrow for the messages beside the full column, it narrows to avatars.
class ChatToolPane extends ConsumerWidget {
  const ChatToolPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizes = context.sizes;
    final compact =
        MediaQuery.sizeOf(context).width -
            sizes.railWidth -
            sizes.toolPaneWidth <
        kChatMessagesMinWidth;
    final accountId = ref.watch(selectedChatAccountIdProvider);
    return ToolPaneScaffold(
      width: compact ? sizes.toolPaneCompactWidth : null,
      body: accountId == null
          ? const SizedBox.shrink()
          : ConversationListPane(accountId: accountId, compact: compact),
    );
  }
}

/// The open conversation, filling the area beside the chat's column.
class ChatSectionView extends StatelessWidget {
  const ChatSectionView({super.key});

  @override
  Widget build(BuildContext context) =>
      const ChatPage(showConversationList: false);
}
