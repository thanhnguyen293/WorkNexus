import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../providers/chat_info_panel_providers.dart';
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

/// Whether the info panel rests beside the chat: there is room for it
/// ([infoRoom]) and the user has not hidden it. Rebuilds on a change.
bool watchChatInfoDocked(WidgetRef ref, {required bool infoRoom}) =>
    infoRoom && (ref.watch(chatInfoPanelVisibleProvider).value ?? true);

/// [watchChatInfoDocked] for callbacks.
bool readChatInfoDocked(WidgetRef ref, {required bool infoRoom}) =>
    infoRoom && (ref.read(chatInfoPanelVisibleProvider).value ?? true);

/// The panel shown beside chat [chat]: the one the user opened, else the
/// info panel when it rests there (see [watchChatInfoDocked]).
ChatSidePanel? effectiveSidePanel(
  WidgetRef ref,
  ChatThreadKey chat, {
  required bool infoRoom,
}) =>
    ref.watch(chatSidePanelProvider(chat)) ??
    (watchChatInfoDocked(ref, infoRoom: infoRoom) ? ChatSidePanel.info : null);

/// Whether the info panel is on screen for chat [chat] (a reply thread
/// takes its place while open).
bool watchChatInfoShown(
  WidgetRef ref,
  ChatThreadKey chat, {
  required bool infoRoom,
}) =>
    ref.watch(openReplyThreadProvider(chat)) == null &&
    effectiveSidePanel(ref, chat, infoRoom: infoRoom) == ChatSidePanel.info;

/// Opens [panel] beside chat [chat] (closing a reply thread), or closes it
/// when it is already open. While the info panel rests beside the chat,
/// "closing" anything returns to it.
void toggleChatSidePanel(
  WidgetRef ref,
  ChatThreadKey chat,
  ChatSidePanel panel, {
  required bool infoRoom,
}) {
  final docked = readChatInfoDocked(ref, infoRoom: infoRoom);
  final notifier = ref.read(chatSidePanelProvider(chat).notifier);
  final shown = notifier.state ?? (docked ? ChatSidePanel.info : null);
  notifier.state = shown == panel || (docked && panel == ChatSidePanel.info)
      ? null
      : panel;
  ref.read(openReplyThreadProvider(chat).notifier).state = null;
}

/// The header's info button. With room it shows or hides the info panel
/// beside the chat and remembers that; without room the panel slides over
/// the messages for the moment, leaving the remembered choice as it was.
Future<Result<void>> toggleChatInfo(
  WidgetRef ref,
  ChatThreadKey chat, {
  required bool infoRoom,
}) async {
  if (!infoRoom) {
    toggleChatSidePanel(ref, chat, ChatSidePanel.info, infoRoom: false);
    return const Ok(null);
  }
  final panel = ref.read(chatSidePanelProvider(chat).notifier);
  final thread = ref.read(openReplyThreadProvider(chat).notifier);
  final docked = readChatInfoDocked(ref, infoRoom: true);
  final shown =
      thread.state == null &&
      (panel.state ?? (docked ? ChatSidePanel.info : null)) ==
          ChatSidePanel.info;
  if (!shown) {
    // Whatever stood in its place gives way.
    panel.state = null;
    thread.state = null;
  } else if (panel.state == ChatSidePanel.info) {
    panel.state = null;
  }
  return ref.read(chatInfoPanelVisibleProvider.notifier).setVisible(!shown);
}

/// Opens [panel] beside chat [chat] (closing a reply thread), leaving it
/// open when it already is.
void openChatSidePanel(WidgetRef ref, ChatThreadKey chat, ChatSidePanel panel) {
  ref.read(chatSidePanelProvider(chat).notifier).state = panel;
  ref.read(openReplyThreadProvider(chat).notifier).state = null;
}

/// From pinned messages or files back to the chat info.
void backToChatInfo(
  WidgetRef ref,
  ChatThreadKey chat, {
  required bool infoRoom,
}) => ref.read(chatSidePanelProvider(chat).notifier).state =
    readChatInfoDocked(ref, infoRoom: infoRoom) ? null : ChatSidePanel.info;

/// Closes the panel beside chat [chat] (a resting info panel stays).
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
      ref.read(appNavProvider.notifier).selectChat();
      ref.read(pickedChatAccountProvider.notifier).state = accountId;
      ref.read(selectedChatGidProvider(accountId).notifier).state = value;
    case Err(:final failure):
      showChatFailure(context, failure);
  }
}
