import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/chat_media_strip.dart';

void main() {
  test('media are matched by their file, not every detail', () {
    const fromList = MessageContent.image(
      fileId: 7,
      name: 'cat.jpg',
      size: 100,
      time: 1,
      width: 636,
      height: 636,
      hasThumb: true,
    );
    const fromMessage = MessageContent.image(
      fileId: 7,
      name: 'cat.jpg',
      size: 100,
      time: 1,
    );
    const video = MessageContent.file(
      fileId: 7,
      name: 'clip.mp4',
      size: 100,
      time: 1,
    );
    expect(indexOfChatMedia([video, fromList], fromMessage), 1);
    expect(indexOfChatMedia([fromList], video), -1);
  });
}
