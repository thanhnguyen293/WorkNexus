import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';

/// Whether a newly arrived message deserves a desktop notification: someone
/// else's live message, notifications on, and the user is not already
/// looking at that chat (window focused with that conversation open).
class ShouldNotifyChatMessage {
  const ShouldNotifyChatMessage();

  bool call(
    ChatMessage message, {
    required bool enabled,
    required bool appFocused,
    required ({String accountId, String chatGid})? visibleChat,
    ChatConversation? conversation,
  }) {
    if (!enabled || message.isMine || message.deleted) return false;
    if (conversation != null &&
        (conversation.hidden || conversation.archived)) {
      return false;
    }
    final looking =
        appFocused &&
        visibleChat?.accountId == message.accountId &&
        visibleChat?.chatGid == message.chatGid;
    return !looking;
  }
}
