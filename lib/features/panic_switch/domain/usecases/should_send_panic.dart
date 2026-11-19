import '../entities/panic_switch_config.dart';
import '../value_objects/debounce_gate.dart';
import '../value_objects/panic_trigger.dart';

/// Whether a triple click on the floating button sends [trigger]'s sticker:
/// it has a chat and its last send is older than the debounce time.
class ShouldSendPanic {
  const ShouldSendPanic();

  bool call({
    required PanicTrigger trigger,
    required PanicSwitchConfig config,
    required DateTime now,
    DateTime? lastSentAt,
  }) =>
      config.chatFor(trigger) != null &&
      debounceAllows(
        last: lastSentAt,
        now: now,
        window: Duration(seconds: config.debounceSeconds),
      );
}
