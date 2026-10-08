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
