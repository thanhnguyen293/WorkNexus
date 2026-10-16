import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:work_nexus/core/platform/app_icon_image.dart';

void main() {
  test('a wide picture becomes a square icon of the icon side', () {
    final wide = img.Image(width: 600, height: 200);
    final png = squareAppIconPng(Uint8List.fromList(img.encodePng(wide)));
    final icon = img.decodePng(png!)!;
    expect(icon.width, kAppIconSide);
    expect(icon.height, kAppIconSide);
  });

  test('an icon file with several sizes gives its largest, not the first', () {
    final small = img.Image(width: 16, height: 16);
    final large = img.Image(width: 64, height: 64)
      ..clear(img.ColorRgba8(255, 0, 0, 255));
    final ico = img.IcoEncoder().encodeImages([small, large]);
    final icon = img.decodePng(squareAppIconPng(Uint8List.fromList(ico))!)!;
    // The 64 px frame, scaled up, stays solid red; the 16 px one is empty.
    expect(icon.getPixel(128, 128).r, 255);
  });

  test('bytes that are not an image give no icon', () {
    expect(squareAppIconPng(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  test('the icon file holds the png whole after a 22-byte header', () {
    final png = Uint8List.fromList([9, 8, 7]);
    final ico = appIconIco(png);
    expect(ico.sublist(0, 6), [0, 0, 1, 0, 1, 0]);
    expect(ico.sublist(14, 18), [3, 0, 0, 0]);
    expect(ico.sublist(18, 22), [22, 0, 0, 0]);
    expect(ico.sublist(22), png);
  });
}
