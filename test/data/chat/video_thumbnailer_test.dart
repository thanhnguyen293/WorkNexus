import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/data/datasources/video_thumbnailer.dart';

void main() {
  test('concurrent requests for one video share a single run', () async {
    final dir = await Directory.systemTemp.createTemp('thumbs');
    addTearDown(() => dir.delete(recursive: true));
    final video = File('${dir.path}/1_clip.mp4')..writeAsBytesSync([0]);
    // A frame already beside the video: no OS tool is run.
    final frame = Uint8List.fromList([1, 2, 3]);
    File('${video.path}.thumb.png').writeAsBytesSync(frame);

    const thumbnailer = VideoThumbnailer();
    final first = thumbnailer.thumbnailOf(video.path);
    final second = thumbnailer.thumbnailOf(video.path);

    // As the upload's two content updates do: both get the same frame.
    expect(identical(first, second), isTrue);
    expect(await first, frame);
    expect(await second, frame);
  });
}
