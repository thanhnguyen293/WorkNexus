import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../value_objects/panic_trigger.dart';

/// The floating button, drawn by the OS above every app.
abstract interface class PanicOverlay {
  /// Shows the button with [image] on it.
  Future<Result<void>> show(Uint8List image);

  Future<Result<void>> hide();

  /// Fires each time the button is clicked three times in a row: with the
  /// left button [PanicTrigger.release], the right one [PanicTrigger.demo].
  Stream<PanicTrigger> get triggers;
}
