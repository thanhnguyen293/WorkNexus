import 'package:freezed_annotation/freezed_annotation.dart';

import '../panic_switch_constants.dart';
import '../value_objects/panic_trigger.dart';
import 'app_ref.dart';

part 'panic_switch_config.freezed.dart';

/// This computer's panic switch settings. Kept per device: who may set it off
/// here, and what it does, is each person's own choice.
@freezed
abstract class PanicSwitchConfig with _$PanicSwitchConfig {
  const PanicSwitchConfig._();

  const factory PanicSwitchConfig({
    /// React to the sticker arriving.
    @Default(true) bool enabled,

    /// Show the floating button that sends the sticker.
    @Default(true) bool overlayVisible,

    /// The team's group: where the release sticker is sent and listened for;
    /// picked by name (`PickDefaultPanicGroup`), null until found.
    String? chatGid,

    /// Demo mode: a second trigger, beside the team's group, that sends and
    /// listens for the demo sticker in [demoChatGid].
    @Default(false) bool demoMode,
    String? demoChatGid,

    /// [demoChatGid] is the user's own chat ("My Cloud"): sending there
    /// switches apps on this computer, as the user's own messages never come
    /// back as incoming.
    @Default(false) bool demoChatIsSelf,

    /// Anyone in the team's group (but you) may set the switch off here;
    /// when off, only [allowedSenderIds] may. The demo chat accepts anyone.
    @Default(true) bool anySender,

    /// Chat user ids whose sticker sets the switch off here when not
    /// [anySender]. Empty = nobody.
    @Default(<int>[]) List<int> allowedSenderIds,

    /// Brought to the front when the switch goes off.
    AppRef? targetApp,
    @Default(<AppRef>[]) List<AppRef> appsToHide,

    /// Also hide WorkNexus itself.
    @Default(true) bool hideSelf,

    /// The least time between two triggers, sending or receiving.
    @Default(PanicSwitchConstants.defaultDebounceSeconds) int debounceSeconds,
  }) = _PanicSwitchConfig;

  /// Where [trigger]'s sticker is sent and listened for; null when it is off.
  String? chatFor(PanicTrigger trigger) => switch (trigger) {
    PanicTrigger.release => chatGid,
    PanicTrigger.demo => demoMode ? demoChatGid : null,
  };

  /// Sending [trigger]'s sticker switches apps on this computer too (the
  /// demo sent to yourself).
  bool sendsToSelf(PanicTrigger trigger) =>
      trigger == PanicTrigger.demo && demoMode && demoChatIsSelf;
}
