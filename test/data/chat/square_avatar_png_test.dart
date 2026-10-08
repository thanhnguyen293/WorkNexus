import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/square_avatar_png.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<(int, int)> _size(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  return (image.width, image.height);
}

void main() {
  test('cuts a wide picture to its centred square', () async {
    final result = await squareAvatarPng(await _png(120, 80));
    final value = (result as Ok<({Uint8List png, int side})>).value;
    expect(value.side, 80);
    expect(await _size(value.png), (80, 80));
  });

  test('scales a large picture down to maxSide', () async {
    final result = await squareAvatarPng(await _png(600, 900), maxSide: 256);
    final value = (result as Ok<({Uint8List png, int side})>).value;
    expect(value.side, 256);
    expect(await _size(value.png), (256, 256));
  });

  test('rejects bytes that are not a picture', () async {
    final result = await squareAvatarPng(Uint8List.fromList([1, 2, 3]));
    expect(result, isA<Err<({Uint8List png, int side})>>());
  });
}
