import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

/// Puts an image on the clipboard.
Future<void> copyImageToClipboard(Uint8List bytes) =>
    Pasteboard.writeImage(bytes);

/// The image on the clipboard, or null when there is none.
Future<Uint8List?> readClipboardImage() => Pasteboard.image;
