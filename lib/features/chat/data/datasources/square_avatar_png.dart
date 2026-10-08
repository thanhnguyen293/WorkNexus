import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';

/// [image] (any format Flutter decodes) cut to its centred square and scaled
/// down to at most [maxSide] px, as PNG — what ZenTao's avatar crop step
/// expects, so it can keep the whole picture.
Future<Result<({Uint8List png, int side})>> squareAvatarPng(
  Uint8List image, {
  int maxSide = 256,
}) async {
  final ui.Image source;
  try {
    final codec = await ui.instantiateImageCodec(image);
    source = (await codec.getNextFrame()).image;
    codec.dispose();
  } on Exception catch (e) {
    return Err(UnexpectedFailure('Unsupported picture', cause: e));
  }
  final crop = math.min(source.width, source.height);
  final side = math.min(crop, maxSide);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    ui.Rect.fromLTWH(
      (source.width - crop) / 2,
      (source.height - crop) / 2,
      crop.toDouble(),
      crop.toDouble(),
    ),
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final square = await recorder.endRecording().toImage(side, side);
  final bytes = await square.toByteData(format: ui.ImageByteFormat.png);
  source.dispose();
  square.dispose();
  return bytes == null
      ? const Err(UnexpectedFailure('Unsupported picture'))
      : Ok((png: bytes.buffer.asUint8List(), side: side));
}
