import 'package:freezed_annotation/freezed_annotation.dart';

import '../panic_switch_constants.dart';
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

    /// The team's group: where the sticker is sent and listened for; picked
    /// by name (`PickDefaultPanicGroup`), null until found.
    String? chatGid,

    /// Test mode: the sticker goes to [testSendChatGid] and is listened for in
    /// [testReceiveChatGid] instead of the team's group, to try the switch
    /// without bothering anyone.
    @Default(false) bool testMode,
    String? testSendChatGid,

    /// [testSendChatGid] is the user's own chat ("My Cloud"): sending there
    /// switches apps on this computer, as the user's own messages never come
    /// back as incoming.
    @Default(false) bool testSendToSelf,
    String? testReceiveChatGid,

    /// Anyone in the chat (but you) may set the switch off here; when off,
    /// only [allowedSenderIds] may.
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

  /// Where the floating button sends the sticker.
  String? get sendChatGid => testMode ? testSendChatGid : chatGid;

  /// Sending switches apps on this computer too (test mode, to yourself).
  bool get sendsToSelf => testMode && testSendToSelf;

  /// Where an arriving sticker sets the switch off.
  String? get receiveChatGid => testMode ? testReceiveChatGid : chatGid;
}
