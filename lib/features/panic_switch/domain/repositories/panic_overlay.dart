import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../value_objects/panic_button_look.dart';
import '../value_objects/panic_trigger.dart';

/// The floating button, drawn by the OS above every app.
abstract interface class PanicOverlay {
  /// Shows the button with [image] on it, as [look] says; showing it again
  /// updates it in place. [demoLabel] names the right-click menu's demo item
  /// (used while [PanicButtonLook.demo]).
  Future<Result<void>> show(
    Uint8List image,
    PanicButtonLook look, {
    required String demoLabel,
  });

  Future<Result<void>> hide();

  /// Fires each time the button goes off: its gesture
  /// [PanicTrigger.release], "Demo" picked from its right-click menu
  /// [PanicTrigger.demo].
  Stream<PanicTrigger> get triggers;
}
