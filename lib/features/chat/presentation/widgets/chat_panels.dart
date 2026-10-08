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

/// Scrolls chat [chat]'s message list to [messageId] (loading older pages
/// as needed) and highlights it.
void jumpToChatMessage(WidgetRef ref, ChatThreadKey chat, int messageId) {
  // Through null, so tapping the same quote again jumps again.
  ref.read(chatJumpRequestProvider(chat).notifier)
    ..state = null
    ..state = messageId;
}

/// The panel shown beside chat [chat]: the one the user opened, else the
/// info panel when there is room for it ([infoRoom]).
ChatSidePanel? effectiveSidePanel(
  WidgetRef ref,
  ChatThreadKey chat, {
  required bool infoRoom,
}) =>
    ref.watch(chatSidePanelProvider(chat)) ??
    (infoRoom ? ChatSidePanel.info : null);

/// Opens [panel] beside chat [chat] (closing a reply thread), or closes it
/// when it is already open. With room, the info panel is always there, so
/// "closing" anything returns to it.
void toggleChatSidePanel(
  WidgetRef ref,
  ChatThreadKey chat,
  ChatSidePanel panel, {
  required bool infoRoom,
}) {
  final notifier = ref.read(chatSidePanelProvider(chat).notifier);
  final shown = notifier.state ?? (infoRoom ? ChatSidePanel.info : null);
  notifier.state = shown == panel || (infoRoom && panel == ChatSidePanel.info)
      ? null
      : panel;
  ref.read(openReplyThreadProvider(chat).notifier).state = null;
}

/// From pinned messages or files back to the chat info.
void backToChatInfo(
  WidgetRef ref,
  ChatThreadKey chat, {
  required bool infoRoom,
}) => ref.read(chatSidePanelProvider(chat).notifier).state = infoRoom
    ? null
    : ChatSidePanel.info;

/// Closes the panel beside chat [chat] (with room, the info panel stays).
void closeChatSidePanel(WidgetRef ref, ChatThreadKey chat) =>
    ref.read(chatSidePanelProvider(chat).notifier).state = null;

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
