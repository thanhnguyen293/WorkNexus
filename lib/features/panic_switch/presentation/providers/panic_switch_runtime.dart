import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../../../chat/domain/entities/chat_message.dart';
import '../../domain/entities/panic_switch_config.dart';
import '../../domain/repositories/panic_overlay.dart';
import '../../domain/repositories/panic_sticker_source.dart';
import '../../domain/usecases/run_panic_switch.dart';
import '../../domain/usecases/send_panic_sticker.dart';
import '../../domain/usecases/should_send_panic.dart';
import '../../domain/usecases/should_trigger_panic.dart';

import 'panic_switch_config_controller.dart';
import 'panic_switch_providers.dart';

/// Reacts to the two events of the panic switch: the sticker arriving (switch
/// apps here) and the floating button's triple click (send the sticker). Holds
/// when each last happened, for the debounce.
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
  final Stream<ChatMessage> incoming;
  DateTime? _lastTriggeredAt;
  DateTime? _lastSentAt;

  /// Switches apps when [message] is the sticker this computer listens for.
  Future<Result<void>> onIncoming(ChatMessage message) async {
    final account = _account();
    final config = _config();
    if (account == null || config == null) return const Ok(null);
    final now = _clock();
    final fire = const ShouldTriggerPanic()(
      message: message,
      config: config,
      accountId: account.id,
      now: now,
      lastTriggeredAt: _lastTriggeredAt,
    );
    if (!fire) return const Ok(null);
    _lastTriggeredAt = now;
    return _run(config);
  }

  /// Sends the sticker to the chosen chat, at most once per debounce time;
  /// sent to yourself, also switches apps here.
  Future<Result<void>> onOverlayTriggered() async {
    final account = _account();
    final config = _config();
    final chatGid = config?.sendChatGid;
    if (account == null || config == null || chatGid == null) {
      return const Ok(null);
    }
    final now = _clock();
    final send = const ShouldSendPanic()(
      config: config,
      now: now,
      lastSentAt: _lastSentAt,
    );
    if (!send) return const Ok(null);
    _lastSentAt = now;
    if (!config.sendsToSelf) {
      return _send(accountId: account.id, chatGid: chatGid);
    }
    // Your own messages never come back as incoming, so trying it on
    // yourself switches here first — even with the chat server down — and
    // the sticker is sent after.
    Result<void> switched = const Ok(null);
    if (config.enabled) {
      _lastTriggeredAt = now;
      switched = await _run(config);
    }
    final sent = await _send(accountId: account.id, chatGid: chatGid);
    return switched.isErr ? switched : sent;
  }

  /// Switches apps now, as the sticker would, without any chat: the
  /// "Try it" button in Settings.
  Future<Result<void>> runNow() async {
    final config = _config();
    if (config == null) return const Ok(null);
    return _run(config);
  }

  /// Puts the floating button up or takes it down.
  Future<Result<void>> showOverlay(bool visible) async {
    if (!visible) return overlay.hide();
    return switch (await _sticker.bytes()) {
      Ok(:final value) => overlay.show(value),
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
    incoming: ref.read(panicChatRepositoryProvider).watchIncoming(),
  ),
);

/// Whether the floating button should be on screen: wanted, with a group to
/// send to, for a user of the ZenTao the feature is offered for.
final panicOverlayVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(panicSwitchAccountProvider) == null) return false;
  final config = ref.watch(panicSwitchConfigProvider).asData?.value;
  return config != null && config.overlayVisible && config.sendChatGid != null;
});
