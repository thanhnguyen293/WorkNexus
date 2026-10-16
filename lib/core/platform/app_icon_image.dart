import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The side of the icon kept on disk; also the largest size Windows draws.
const kAppIconSide = 256;

/// [bytes] (any image the decoder knows) cropped to a square around its
/// centre and scaled to [kAppIconSide] pixels, as PNG; null when it is not an
/// image. Runs off the UI isolate: a photo is slow to decode.
Uint8List? squareAppIconPng(Uint8List bytes) {
  final image = _decode(bytes);
  if (image == null || image.width == 0 || image.height == 0) return null;
  final square = img.copyResizeCropSquare(image, size: kAppIconSide);
  return Uint8List.fromList(img.encodePng(square));
}

/// The picture in [bytes]; of an icon file (one image per size), the largest,
/// which a plain decode would not pick (it takes the first, often 16 pixels).
img.Image? _decode(Uint8List bytes) {
  final icon = img.IcoDecoder();
  if (!icon.isValidFile(bytes) || icon.startDecode(bytes) == null) {
    return img.decodeImage(bytes);
  }
  img.Image? largest;
  for (var i = 0; i < icon.numFrames(); i++) {
    final frame = icon.decodeFrame(i);
    if (frame != null && (largest == null || frame.width > largest.width)) {
      largest = frame;
    }
  }
  return largest;
}

/// An `.ico` holding the [kAppIconSide]-pixel [png] as its one image: Windows
/// (Vista and later) reads a PNG inside an icon, and the tray only takes icon
/// files.
Uint8List appIconIco(Uint8List png) {
  final data = ByteData(22);
  data
    ..setUint16(2, 1, Endian.little) // Type: icon.
    ..setUint16(4, 1, Endian.little) // One image.
    // Width and height 0 mean 256.
    ..setUint16(10, 1, Endian.little) // Colour planes.
    ..setUint16(12, 32, Endian.little) // Bits per pixel.
    ..setUint32(14, png.length, Endian.little)
    ..setUint32(18, 22, Endian.little); // Where the image starts.
  return Uint8List.fromList([...data.buffer.asUint8List(), ...png]);
}
