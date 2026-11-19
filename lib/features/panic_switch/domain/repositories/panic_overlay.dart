import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../value_objects/panic_button_look.dart';
import '../value_objects/panic_trigger.dart';

/// The floating button, drawn by the OS above every app.
abstract interface class PanicOverlay {
  /// Shows the button with [image] on it, as [look] says; showing it again
  /// updates it in place.
  Future<Result<void>> show(Uint8List image, PanicButtonLook look);

  Future<Result<void>> hide();

  /// Fires each time the button's gesture is made: with the left button
  /// [PanicTrigger.release], the right one [PanicTrigger.demo].
  Stream<PanicTrigger> get triggers;
}
