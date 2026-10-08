import 'dart:typed_data';

/// Pixel size of an image read from its header (PNG, JPEG, GIF, WebP, BMP),
/// without decoding it. Null when the format is not recognised.
({int width, int height})? imageHeaderSize(Uint8List b) {
  if (b.length < 24) return null;
  final data = ByteData.sublistView(b);
  // PNG: IHDR right after the 8-byte signature.
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return (width: data.getUint32(16), height: data.getUint32(20));
  }
  // GIF: logical screen size, little-endian.
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
    return (
      width: data.getUint16(6, Endian.little),
      height: data.getUint16(8, Endian.little),
    );
  }
  // BMP: BITMAPINFOHEADER width/height (height may be negative = top-down).
  if (b[0] == 0x42 && b[1] == 0x4D && b.length >= 26) {
    return (
      width: data.getInt32(18, Endian.little).abs(),
      height: data.getInt32(22, Endian.little).abs(),
    );
  }
  // WebP: RIFF....WEBP with a VP8 / VP8L / VP8X chunk.
  if (b.length >= 30 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    final chunk = String.fromCharCodes(b.sublist(12, 16));
    switch (chunk) {
      case 'VP8 ':
        return (
          width: data.getUint16(26, Endian.little) & 0x3FFF,
          height: data.getUint16(28, Endian.little) & 0x3FFF,
        );
      case 'VP8L':
        final bits = data.getUint32(21, Endian.little);
        return (
          width: (bits & 0x3FFF) + 1,
          height: ((bits >> 14) & 0x3FFF) + 1,
        );
      case 'VP8X':
        int u24(int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
        return (width: u24(24) + 1, height: u24(27) + 1);
    }
    return null;
  }
  // JPEG: walk the segments to the first start-of-frame marker.
  if (b[0] == 0xFF && b[1] == 0xD8) {
    var i = 2;
    while (i + 9 < b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      final isSof =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isSof) {
        return (width: data.getUint16(i + 7), height: data.getUint16(i + 5));
      }
      i += 2 + data.getUint16(i + 2);
    }
  }
  return null;
}
