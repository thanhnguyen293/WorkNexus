import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/value_objects/chat_avatar_crop.dart';

/// [image] (any format Flutter decodes) cut to the square [crop] (its centred
/// square when null) and scaled down to at most [maxSide] px, as PNG — what
/// ZenTao's avatar crop step expects, so it can keep the whole picture.
Future<Result<({Uint8List png, int side})>> squareAvatarPng(
  Uint8List image, {
  ChatAvatarCrop? crop,
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
  final fit = math.min(source.width, source.height).toDouble();
  // Kept inside the picture: a crop from a rounded zoom may overshoot a px.
  final cropSide = (crop?.side ?? fit).clamp(1.0, fit);
  final left = (crop?.left ?? (source.width - cropSide) / 2).clamp(
    0.0,
    source.width - cropSide,
  );
  final top = (crop?.top ?? (source.height - cropSide) / 2).clamp(
    0.0,
    source.height - cropSide,
  );
  final side = math.min(cropSide.round(), maxSide);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    source,
    ui.Rect.fromLTWH(left, top, cropSide, cropSide),
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
