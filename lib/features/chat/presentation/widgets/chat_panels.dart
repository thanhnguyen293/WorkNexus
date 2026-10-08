import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../providers/chat_providers.dart';
import 'chat_snack.dart';

/// Opens the reply thread that [messageId] belongs to beside chat [chat].
void openReplyThread(WidgetRef ref, ChatThreadKey chat, int messageId) {
  final replies = ref.read(chatRepliesProvider(chat)).asData?.value ?? const [];
  ref.read(openReplyThreadProvider(chat).notifier).state = ref
      .read(chatControllerProvider)
      .threadRootOf(messageId, replies);
  // One panel beside the chat at a time.
  ref.read(chatSidePanelProvider(chat).notifier).state = null;
}

/// Opens [panel] beside chat [chat] (closing a reply thread), or closes it
/// when it is already open.
void toggleChatSidePanel(
  WidgetRef ref,
  ChatThreadKey chat,
  ChatSidePanel panel,
) {
  final notifier = ref.read(chatSidePanelProvider(chat).notifier);
  notifier.state = notifier.state == panel ? null : panel;
  ref.read(openReplyThreadProvider(chat).notifier).state = null;
  if (panel == ChatSidePanel.info) {
    ref.read(chatInfoAutoOpenProvider.notifier).state =
        notifier.state == ChatSidePanel.info;
  }
}

/// Closes the panel beside chat [chat]; closing the info panel also stops
/// it opening by itself for the next chats.
void closeChatSidePanel(WidgetRef ref, ChatThreadKey chat) {
  final notifier = ref.read(chatSidePanelProvider(chat).notifier);
  if (notifier.state == ChatSidePanel.info) {
    ref.read(chatInfoAutoOpenProvider.notifier).state = false;
  }
  notifier.state = null;
}

/// Least width of the chat area for the info panel to open by itself: the
/// messages keep about 560 px beside the 340 px panel.
const double kChatInfoAutoOpenWidth = 900;

/// On opening a chat that is [width] wide: shows its info panel when the
/// user has not turned that off, there is room, and nothing else is open
/// beside it.
void autoOpenChatInfo(WidgetRef ref, ChatThreadKey chat, double width) {
  if (width < kChatInfoAutoOpenWidth) return;
  if (!ref.read(chatInfoAutoOpenProvider)) return;
  if (ref.read(openReplyThreadProvider(chat)) != null) return;
  final notifier = ref.read(chatSidePanelProvider(chat).notifier);
  notifier.state ??= ChatSidePanel.info;
}

/// Switches the chat view to the one-to-one chat with [userId] (created on
/// the server if it does not exist yet).
Future<void> openDirectChatWith(
  BuildContext context,
  WidgetRef ref, {
  required String accountId,
  required int userId,
}) async {
  final result = await ref
      .read(chatControllerProvider)
      .openDirectChat(accountId, userId);
  if (!context.mounted) return;
  switch (result) {
    case Ok(:final value):
      showChatView(ref);
      ref.read(pickedChatAccountProvider.notifier).state = accountId;
      ref.read(selectedChatGidProvider(accountId).notifier).state = value;
    case Err(:final failure):
      showChatFailure(context, failure);
  }
}
