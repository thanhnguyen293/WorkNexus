import '../entities/panic_switch_config.dart';
import '../value_objects/debounce_gate.dart';

/// Whether a triple click on the floating button sends the sticker: a group
/// is chosen and the last send is older than the debounce time.
class ShouldSendPanic {
  const ShouldSendPanic();

  bool call({
    required PanicSwitchConfig config,
    required DateTime now,
    DateTime? lastSentAt,
  }) =>
      config.sendChatGid != null &&
      debounceAllows(
        last: lastSentAt,
        now: now,
        window: Duration(seconds: config.debounceSeconds),
      );
}
