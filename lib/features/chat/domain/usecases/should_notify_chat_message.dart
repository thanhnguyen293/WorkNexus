import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';
import '../entities/chat_message_reaction.dart';

/// Whether a newly arrived message deserves a desktop notification: someone
/// else's live message, notifications on, and the user is not already
/// looking at that chat (window focused with that conversation open) —
/// unless [whileViewing] asks to be told even then. A reaction never is one
/// while [reactions] are on; off, an emoji reply is a message like any
/// other.
class ShouldNotifyChatMessage {
  const ShouldNotifyChatMessage();

  bool call(
    ChatMessage message, {
    required bool enabled,
    required bool appFocused,
    required ({String accountId, String chatGid})? visibleChat,
    ChatConversation? conversation,
    bool whileViewing = false,
    bool reactions = true,
  }) {
    if (!enabled ||
        message.isMine ||
        message.deleted ||
        (reactions && message.isReaction)) {
      return false;
    }
    if (conversation != null &&
        (conversation.hidden || conversation.archived || conversation.muted)) {
      return false;
    }
    if (whileViewing) return true;
    final looking =
        appFocused &&
        visibleChat?.accountId == message.accountId &&
        visibleChat?.chatGid == message.chatGid;
    return !looking;
  }
}
