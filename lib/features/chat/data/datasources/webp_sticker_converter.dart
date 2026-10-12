import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/sticker_pack_source.dart';

/// Converts imported stickers into WebP at [size] without any native tool:
/// an animated Telegram sticker (`.tgs`: gzipped Lottie JSON) is drawn frame
/// by frame with `lottie`, and `image` encodes the result (in a background
/// isolate, as encoding is the slow part).
class WebpStickerConverter implements StickerConverter {
  const WebpStickerConverter({this.size = 128, this.maxFps = 25});

  /// The longest side of a sticker, in pixels: the bundled sets' size
  /// (Telegram draws stickers at 512).
  final int size;

  /// Frames per second at most; a 60 fps animation is sampled down.
  final int maxFps;

  @override
  Future<Result<Uint8List>> animatedToWebp(Uint8List tgs) async {
    try {
      final composition =
          await LottieComposition.decodeGZip(tgs) ??
          LottieComposition.parseJsonBytes(tgs);
      final seconds = composition.duration.inMicroseconds / 1e6;
      final fps = math.min(composition.frameRate, maxFps.toDouble());
      final count = math.max(1, (seconds * fps).round());
      // Spread over the whole animation, so it loops at its own speed.
      final frameMs = math.max(1, (seconds * 1000 / count).round());
      final drawable = LottieDrawable(composition);
      final frames = <Uint8List>[];
      for (var i = 0; i < count; i++) {
        drawable.setProgress(i / count);
        frames.add(await _render(drawable));
      }
      final size = this.size;
      return Ok(await Isolate.run(() => _encode(frames, size, frameMs)));
    } on Object catch (e) {
      // lottie throws Errors as well as Exceptions on a malformed file.
      return Err(
        ParseFailure('An animated sticker could not be converted', cause: e),
      );
    }
  }

  @override
  Future<Result<Uint8List>> stillToWebp(Uint8List image) async {
    try {
      final size = this.size;
      return Ok(await Isolate.run(() => _fitStill(image, size)));
    } on Object catch (e) {
      return Err(ParseFailure('A sticker image could not be read', cause: e));
    }
  }

  /// One frame as straight (not premultiplied) RGBA, what WebP stores.
  Future<Uint8List> _render(LottieDrawable drawable) async {
    final recorder = ui.PictureRecorder();
    final side = size.toDouble();
    drawable.draw(ui.Canvas(recorder), ui.Rect.fromLTWH(0, 0, side, side));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) throw StateError('A frame could not be read');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

/// [bytes] scaled down so its longest side is at most [size] (a smaller
/// image is not blown up), as lossless WebP: a still has crisp edges to keep.
Uint8List _fitStill(Uint8List bytes, int size) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Not an image');
  final fitted = image.width <= size && image.height <= size
      ? image
      : image.width >= image.height
      ? img.copyResize(
          image,
          width: size,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          image,
          height: size,
          interpolation: img.Interpolation.average,
        );
  return img.WebPEncoder().encode(fitted, singleFrame: true);
}

Uint8List _encode(List<Uint8List> frames, int size, int frameMs) {
  img.Image? animation;
  for (final rgba in frames) {
    final frame = img.Image.fromBytes(
      width: size,
      height: size,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
      frameDuration: frameMs,
    );
    final first = animation;
    if (first == null) {
      animation = frame;
    } else {
      first.addFrame(frame);
    }
  }
  final first = animation;
  if (first == null) throw StateError('No frames to encode');
  // Lossy keeps an animated sticker to tens of kilobytes; alpha stays exact.
  return img.WebPEncoder(lossless: false).encode(first);
}
