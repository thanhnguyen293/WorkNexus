import '../entities/panic_switch_config.dart';
import '../value_objects/debounce_gate.dart';
import '../value_objects/panic_trigger.dart';

/// Whether the floating button sends [trigger]'s sticker: the feature is on,
/// the trigger has a chat and its last send is older than the debounce time.
class ShouldSendPanic {
  const ShouldSendPanic();

  bool call({
    required PanicTrigger trigger,
    required PanicSwitchConfig config,
    required DateTime now,
    DateTime? lastSentAt,
  }) =>
      config.enabled &&
      config.chatFor(trigger) != null &&
      debounceAllows(
        last: lastSentAt,
        now: now,
        window: Duration(seconds: config.debounceSeconds),
      );
}
