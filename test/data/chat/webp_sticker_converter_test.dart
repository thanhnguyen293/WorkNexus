import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/data/datasources/webp_sticker_converter.dart';

Map<String, dynamic> _value(Object k) => {'a': 0, 'k': k};

/// One second at 30 fps of a red dot crossing a transparent 512×512 canvas —
/// the shape of a Telegram animated sticker.
final _lottie = {
  'v': '5.7.4',
  'fr': 30,
  'ip': 0,
  'op': 30,
  'w': 512,
  'h': 512,
  'layers': [
    {
      'ty': 4,
      'ind': 1,
      'ip': 0,
      'op': 30,
      'st': 0,
      'ks': {
        'o': _value(100),
        'r': _value(0),
        'a': _value([0, 0, 0]),
        's': _value([100, 100, 100]),
        'p': {
          'a': 1,
          'k': [
            {
              't': 0,
              's': [96, 256, 0],
              'i': {'x': 0.5, 'y': 0.5},
              'o': {'x': 0.5, 'y': 0.5},
            },
            {
              't': 30,
              's': [416, 256, 0],
            },
          ],
        },
      },
      'shapes': [
        {
          'ty': 'gr',
          'it': [
            {
              'ty': 'el',
              'p': _value([0, 0]),
              's': _value([160, 160]),
            },
            {
              'ty': 'fl',
              'c': _value([1, 0, 0, 1]),
              'o': _value(100),
            },
            {
              'ty': 'tr',
              'p': _value([0, 0]),
              'a': _value([0, 0]),
              's': _value([100, 100]),
              'r': _value(0),
              'o': _value(100),
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('an animated sticker becomes a 128px animated WebP', (
    tester,
  ) async {
    final tgs = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode(_lottie))),
    );

    final result = await tester.runAsync(
      () => const WebpStickerConverter().animatedToWebp(tgs),
    );

    final webp = switch (result) {
      Ok(:final value) => value,
      _ => fail('not converted: $result'),
    };
    final decoded = img.decodeWebP(webp);
    expect(decoded, isNotNull);
    final animation = decoded!;
    expect(animation.width, 128);
    // One second sampled at the 25 fps cap, looping forever.
    expect(animation.numFrames, 25);
    expect(animation.loopCount, 0);
    expect(animation.frames.first.frameDuration, 40);
    // The dot moves: it starts on the left and ends on the right…
    final first = animation.frames.first;
    final last = animation.frames.last;
    expect(first.getPixel(24, 64).r, greaterThan(200));
    expect(last.getPixel(24, 64).a, lessThan(30));
    expect(last.getPixel(100, 64).r, greaterThan(200));
    // …over a canvas that stays transparent.
    expect(first.getPixel(64, 4).a, 0);
  });

  testWidgets('a file that is not a Lottie animation fails cleanly', (
    tester,
  ) async {
    final result = await tester.runAsync(
      () => const WebpStickerConverter().animatedToWebp(
        Uint8List.fromList(utf8.encode('not lottie')),
      ),
    );

    expect(result?.failureOrNull, isA<ParseFailure>());
  });

  testWidgets('a still sticker is scaled to 128px WebP, keeping its shape', (
    tester,
  ) async {
    final wide = img.Image(width: 512, height: 256, numChannels: 4)
      ..clear(img.ColorRgba8(0, 128, 255, 255));
    final small = img.Image(width: 100, height: 100, numChannels: 4);

    final scaled = await tester.runAsync(
      () => const WebpStickerConverter().imageToWebp(img.encodePng(wide)),
    );
    final kept = await tester.runAsync(
      () => const WebpStickerConverter().imageToWebp(img.encodePng(small)),
    );

    final out = img.decodeWebP(scaled!.valueOrNull!)!;
    expect((out.width, out.height), (128, 64));
    expect(out.getPixel(10, 10).b, greaterThan(240));
    // Not blown up past its own size.
    expect(img.decodeWebP(kept!.valueOrNull!)!.width, 100);
  });
}
