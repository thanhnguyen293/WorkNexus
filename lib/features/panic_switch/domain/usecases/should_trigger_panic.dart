import '../entities/panic_incoming_message.dart';
import '../entities/panic_switch_config.dart';
import '../panic_switch_constants.dart';
import '../value_objects/debounce_gate.dart';
import '../value_objects/panic_trigger.dart';

/// Whether an arriving [message] sets [trigger] off on this computer: its
/// sticker, fresh, in its chat of [accountId], from an allowed sender (anyone
/// but you, by default; anyone in the demo chat), and not within the debounce
/// time of [trigger]'s last run.
class ShouldTriggerPanic {
  const ShouldTriggerPanic();

  bool call({
    required PanicTrigger trigger,
    required PanicIncomingMessage message,
    required PanicSwitchConfig config,
    required String accountId,
    required DateTime now,
    DateTime? lastTriggeredAt,
  }) {
    if (!config.enabled || message.isMine || message.deleted) return false;
    final chatGid = config.chatFor(trigger);
    if (chatGid == null ||
        message.accountId != accountId ||
        message.chatGid != chatGid) {
      return false;
    }
    if (trigger == PanicTrigger.release &&
        !config.anySender &&
        !config.allowedSenderIds.contains(message.senderId)) {
      return false;
    }
    if (triggerOf(message.imageName) != trigger) return false;
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

  /// The trigger an image named [imageName] is the sticker of, if any.
  static PanicTrigger? triggerOf(String? imageName) =>
      imageName == null ? null : PanicTrigger.ofSticker(imageName);
}
