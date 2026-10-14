import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/square_avatar_png.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_avatar_crop.dart';

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

/// [width]×[height], red on the left half and blue on the right.
Future<Uint8List> _halves(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    )
    ..drawRect(
      ui.Rect.fromLTWH(width / 2, 0, width / 2, height.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF0000FF),
    );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// The RGBA of [png]'s centre pixel.
Future<List<int>> _centre(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final rgba = (await image.toByteData())!;
  final at = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
  return [for (var i = 0; i < 4; i++) rgba.getUint8(at + i)];
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

  test('keeps the chosen square', () async {
    final result = await squareAvatarPng(
      await _halves(200, 100),
      crop: const ChatAvatarCrop(left: 100, top: 0, side: 100),
    );
    final value = (result as Ok<({Uint8List png, int side})>).value;
    expect(value.side, 100);
    expect(await _centre(value.png), [0, 0, 255, 255]);
  });

  test('keeps a square that overshoots the picture inside it', () async {
    final result = await squareAvatarPng(
      await _halves(200, 100),
      crop: const ChatAvatarCrop(left: -10, top: 5, side: 140),
    );
    final value = (result as Ok<({Uint8List png, int side})>).value;
    expect(value.side, 100);
    expect(await _centre(value.png), [255, 0, 0, 255]);
  });

  test('rejects bytes that are not a picture', () async {
    final result = await squareAvatarPng(Uint8List.fromList([1, 2, 3]));
    expect(result, isA<Err<({Uint8List png, int side})>>());
  });
}
