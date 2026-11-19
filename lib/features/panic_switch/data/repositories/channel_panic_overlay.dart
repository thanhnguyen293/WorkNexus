import 'package:flutter/services.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/panic_overlay.dart';
import '../../domain/value_objects/panic_button_look.dart';
import '../../domain/value_objects/panic_trigger.dart';
import '../datasources/panic_switch_channel.dart';

/// [PanicOverlay] drawn by the runner's native code, as its own always-on-top
/// window: the Flutter window cannot float over other apps while it may itself
/// be hidden.
class ChannelPanicOverlay implements PanicOverlay {
  ChannelPanicOverlay(this._channel);

  final PanicSwitchChannel _channel;

  @override
  Stream<PanicTrigger> get triggers => _channel.triggers.map(
    (which) => which == 'demo' ? PanicTrigger.demo : PanicTrigger.release,
  );

  @override
  Future<Result<void>> show(
    Uint8List image,
    PanicButtonLook look, {
    required String demoLabel,
  }) => _guard(
    () => _channel.showOverlay(
      image,
      size: look.size,
      opacity: look.opacity,
      gesture: look.gesture.wire,
      demoLabel: look.demo ? demoLabel : null,
    ),
  );

  @override
  Future<Result<void>> hide() => _guard(_channel.hideOverlay);

  static Future<Result<void>> _guard(Future<void> Function() run) async {
    try {
      await run();
      return const Ok(null);
    } on PlatformException catch (e) {
      return Err(UnexpectedFailure('Floating button: ${e.message}', cause: e));
    } on MissingPluginException catch (e) {
      return Err(UnexpectedFailure('Floating button unavailable', cause: e));
    }
  }
}
