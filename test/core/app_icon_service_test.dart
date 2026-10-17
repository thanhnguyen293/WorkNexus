import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:work_nexus/core/platform/app_icon_service.dart';

void main() {
  late Directory dir;
  late AppIconService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('app_icon_');
    service = AppIconService(folder: () async => Directory('${dir.path}/kept'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File source(String name, List<int> bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  test('an image becomes the icon in use', () async {
    final png = img.encodePng(img.Image(width: 40, height: 20));
    expect(await service.choose(source('a.png', png).path), isTrue);
    expect(await service.current(), isNotNull);
  });

  test('a corrupt image is refused, not thrown, and keeps the icon', () async {
    final png = img.encodePng(img.Image(width: 40, height: 20));
    await service.choose(source('a.png', png).path);
    final before = await service.current();
    final broken = Uint8List.fromList(png.sublist(0, png.length ~/ 2));
    expect(await service.choose(source('b.png', broken).path), isFalse);
    expect((await service.current())?.path, before?.path);
  });

  test('a file that cannot be read is refused, not thrown', () async {
    expect(await service.choose('${dir.path}/missing.png'), isFalse);
  });
}
