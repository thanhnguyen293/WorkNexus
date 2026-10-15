import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_cover_decode.dart';

MessageContent _image({int? width, int? height}) => MessageContent.image(
  fileId: 1,
  name: 'p.jpg',
  size: 10,
  time: 0,
  width: width,
  height: height,
);

void main() {
  test(
    'a landscape photo is bounded by its height, so cover never upscales',
    () {
      expect(coverDecodeSize(_image(width: 4000, height: 3000), 112), (
        cacheWidth: null,
        cacheHeight: 112,
      ));
    },
  );

  test('a portrait or square photo is bounded by its width', () {
    expect(coverDecodeSize(_image(width: 3000, height: 4000), 112), (
      cacheWidth: 112,
      cacheHeight: null,
    ));
    expect(coverDecodeSize(_image(width: 500, height: 500), 112), (
      cacheWidth: 112,
      cacheHeight: null,
    ));
  });

  test('unknown dimensions decode in full; a video frame by height', () {
    expect(coverDecodeSize(_image(), 112), (
      cacheWidth: null,
      cacheHeight: null,
    ));
    const video = MessageContent.file(
      fileId: 2,
      name: 'clip.mp4',
      size: 10,
      time: 0,
    );
    expect(coverDecodeSize(video, 112), (cacheWidth: null, cacheHeight: 112));
  });
}
