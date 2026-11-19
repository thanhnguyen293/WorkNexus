import 'dart:typed_data';

import '../../../../core/error/result.dart';

/// The floating button, drawn by the OS above every app.
abstract interface class PanicOverlay {
  /// Shows the button with [image] on it.
  Future<Result<void>> show(Uint8List image);

  Future<Result<void>> hide();

  /// Fires each time the button is clicked three times in a row.
  Stream<void> get triggers;
}
