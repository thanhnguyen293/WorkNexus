import 'package:freezed_annotation/freezed_annotation.dart';

import '../panic_switch_constants.dart';
import '../value_objects/panic_button_look.dart';
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

    /// The floating button's width (logical pixels), opacity (0–1) and the
    /// gesture that sets it off.
    @Default(PanicButtonChoices.defaultSize) int overlaySize,
    @Default(PanicButtonChoices.defaultOpacity) double overlayOpacity,
    @Default(PanicGesture.tripleClick) PanicGesture overlayGesture,

    /// The team's group: where the release sticker is sent and listened for;
    /// picked by name (`PickDefaultPanicGroup`), null until found.
    String? chatGid,

    /// Demo mode: a second trigger, beside the team's group, that sends and
    /// listens for the demo sticker in [demoChatGid].
    @Default(false) bool demoMode,
    String? demoChatGid,

    /// Anyone in the team's group (but you) may set the switch off here;
    /// when off, only [allowedSenderIds] may. The demo chat accepts anyone.
    @Default(true) bool anySender,

    /// Chat user ids whose sticker sets the switch off here when not
    /// [anySender]. Empty = nobody.
    @Default(<int>[]) List<int> allowedSenderIds,

    /// Opened or brought forward when the switch goes off, the first in
    /// front; every other running app is hidden.
    @Default(<AppRef>[]) List<AppRef> appsToOpen,

    /// Also hide WorkNexus itself.
    @Default(true) bool hideSelf,

    /// The least time between two triggers, sending or receiving.
    @Default(PanicSwitchConstants.defaultDebounceSeconds) int debounceSeconds,
  }) = _PanicSwitchConfig;

  PanicButtonLook get overlayLook =>
      (size: overlaySize, opacity: overlayOpacity, gesture: overlayGesture);

  /// Where [trigger]'s sticker is sent and listened for; null when it is off.
  String? chatFor(PanicTrigger trigger) => switch (trigger) {
    PanicTrigger.release => chatGid,
    PanicTrigger.demo => demoMode ? demoChatGid : null,
  };
}
