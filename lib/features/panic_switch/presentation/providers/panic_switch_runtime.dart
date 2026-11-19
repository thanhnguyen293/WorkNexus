import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/panic_incoming_message.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/repositories/panic_overlay.dart';
import '../../domain/repositories/panic_sticker_source.dart';
import '../../domain/usecases/run_panic_switch.dart';
import '../../domain/usecases/send_panic_sticker.dart';
import '../../domain/usecases/should_send_panic.dart';
import '../../domain/usecases/should_trigger_panic.dart';
import '../../domain/value_objects/panic_button_look.dart';
import '../../domain/value_objects/panic_trigger.dart';
import 'panic_switch_config_controller.dart';
import 'panic_switch_providers.dart';

/// Reacts to the two events of the panic switch: the sticker arriving (switch
/// apps here) and the floating button's triple click (send the sticker), for
/// each [PanicTrigger] side by side. Holds when each last happened, per
/// trigger, for the debounce.
class PanicSwitchRuntime {
  PanicSwitchRuntime({
    required this._account,
    required this._config,
    required this._run,
    required this._send,
    required this.overlay,
    required this._sticker,
    required this.incoming,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Account? Function() _account;
  final PanicSwitchConfig? Function() _config;
  final RunPanicSwitch _run;
  final SendPanicSticker _send;
  final PanicStickerSource _sticker;
  final DateTime Function() _clock;
  final PanicOverlay overlay;

  /// Messages from other people as they arrive.
  final Stream<PanicIncomingMessage> incoming;
  final _lastTriggeredAt = <PanicTrigger, DateTime>{};
  final _lastSentAt = <PanicTrigger, DateTime>{};

  /// Switches apps when [message] is a sticker this computer listens for.
  Future<Result<void>> onIncoming(PanicIncomingMessage message) async {
    final account = _account();
    final config = _config();
    final trigger = ShouldTriggerPanic.triggerOf(message.imageName);
    if (account == null || config == null || trigger == null) {
      return const Ok(null);
    }
    final now = _clock();
    final fire = const ShouldTriggerPanic()(
      trigger: trigger,
      message: message,
      config: config,
      accountId: account.id,
      now: now,
      lastTriggeredAt: _lastTriggeredAt[trigger],
    );
    if (!fire) return const Ok(null);
    _lastTriggeredAt[trigger] = now;
    return _run(config);
  }

  /// Sends [trigger]'s sticker to its chat and switches apps here too, at
  /// most once per debounce time. Switching comes first, so it works even
  /// with the chat server down; a send failure is still reported.
  Future<Result<void>> onOverlayTriggered(PanicTrigger trigger) async {
    final account = _account();
    final config = _config();
    final chatGid = config?.chatFor(trigger);
    if (account == null || config == null || chatGid == null) {
      return const Ok(null);
    }
    final now = _clock();
    final send = const ShouldSendPanic()(
      trigger: trigger,
      config: config,
      now: now,
      lastSentAt: _lastSentAt[trigger],
    );
    if (!send) return const Ok(null);
    _lastSentAt[trigger] = now;
    _lastTriggeredAt[trigger] = now;
    final switched = await _run(config);
    final sent = await _send(
      trigger: trigger,
      accountId: account.id,
      chatGid: chatGid,
    );
    return switched.isErr ? switched : sent;
  }

  /// Puts the floating button up as [look] says, or takes it down (null).
  /// [demoLabel] names the right-click menu's demo item.
  Future<Result<void>> showOverlay(
    PanicButtonLook? look, {
    required String demoLabel,
  }) async {
    if (look == null) return overlay.hide();
    return switch (await _sticker.bytes()) {
      Ok(:final value) => overlay.show(value, look, demoLabel: demoLabel),
      Err(:final failure) => Err(failure),
    };
  }
}

final panicSwitchRuntimeProvider = Provider<PanicSwitchRuntime>(
  (ref) => PanicSwitchRuntime(
    account: () => ref.read(panicSwitchAccountProvider),
    config: () => ref.read(panicSwitchConfigProvider).asData?.value,
    run: getIt<RunPanicSwitch>(),
    send: getIt<SendPanicSticker>(),
    overlay: getIt<PanicOverlay>(),
    sticker: getIt<PanicStickerSource>(),
    incoming: ref.read(panicChatGatewayProvider).watchIncoming(),
  ),
);

/// How the floating button should be on screen, or null to take it down: it
/// is wanted, with a chat to send to (the team's group or the demo chat), for
/// a user of the ZenTao the feature is offered for.
final panicOverlayLookProvider = Provider<PanicButtonLook?>((ref) {
  if (ref.watch(panicSwitchAccountProvider) == null) return null;
  final config = ref.watch(panicSwitchConfigProvider).asData?.value;
  if (config == null || !config.enabled || !config.overlayVisible) return null;
  final hasChat = PanicTrigger.values.any((t) => config.chatFor(t) != null);
  return hasChat ? config.overlayLook : null;
});
