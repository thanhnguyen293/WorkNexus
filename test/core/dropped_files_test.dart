import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/util/dropped_files.dart';

void main() {
  final bytes = Uint8List(0);

  test('knows the images the editor shows inline', () {
    expect(isInlineImageName('shot.PNG'), isTrue);
    expect(isInlineImageName('photo.jpeg'), isTrue);
    expect(isInlineImageName('report.pdf'), isFalse);
    expect(isInlineImageName('no-extension'), isFalse);
  });

  test('splits dropped files into images and the rest, in order', () {
    final split = splitDroppedImages([
      (name: 'a.png', bytes: bytes),
      (name: 'log.txt', bytes: bytes),
      (name: 'b.gif', bytes: bytes),
    ]);
    expect(split.images.map((f) => f.name), ['a.png', 'b.gif']);
    expect(split.others.map((f) => f.name), ['log.txt']);
  });
}
