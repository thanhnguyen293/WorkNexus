import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

/// Puts an image on the clipboard.
Future<void> copyImageToClipboard(Uint8List bytes) =>
    Pasteboard.writeImage(bytes);
