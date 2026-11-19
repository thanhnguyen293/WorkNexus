import '../../../chat/domain/entities/chat_message.dart';
import '../../../chat/domain/value_objects/message_content.dart';
import '../entities/panic_switch_config.dart';
import '../panic_switch_constants.dart';
import '../value_objects/debounce_gate.dart';

/// Whether an arriving [message] sets the panic switch off on this computer:
/// the "Thầy vô" sticker, fresh, in the chosen chat of [accountId], from an
/// allowed sender (anyone but you, by default), and not within the debounce time of the last trigger.
class ShouldTriggerPanic {
  const ShouldTriggerPanic();

  bool call({
    required ChatMessage message,
    required PanicSwitchConfig config,
    required String accountId,
    required DateTime now,
    DateTime? lastTriggeredAt,
  }) {
    if (!config.enabled || message.isMine || message.deleted) return false;
    if (message.accountId != accountId ||
        message.chatGid != config.receiveChatGid) {
      return false;
    }
    if (!config.anySender &&
        !config.allowedSenderIds.contains(message.senderId)) {
      return false;
    }
    if (!isPanicSticker(message.content)) return false;
    // Both ways: the sender's clock may run a little ahead of this one.
    if (now.difference(message.sentAt).abs() >
        PanicSwitchConstants.freshWindow) {
      return false;
    }
    return debounceAllows(
      last: lastTriggeredAt,
      now: now,
      window: Duration(seconds: config.debounceSeconds),
    );
  }

  static bool isPanicSticker(MessageContent content) => switch (content) {
    ImageContent(:final name) =>
      name.toLowerCase() == PanicSwitchConstants.stickerFileName,
    _ => false,
  };
}
