import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/chat_media_kind.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

ChatMessage _message(MessageContent content, SendState state) => ChatMessage(
  accountId: 'zt',
  gid: 'g1',
  chatGid: 'c1',
  senderId: 1,
  sentAt: DateTime(2026, 10, 10),
  content: content,
  isMine: true,
  sendState: state,
);

FileContent _file(String name, int fileId) =>
    FileContent(fileId: fileId, name: name, size: 10, time: 0);

void main() {
  test('a video is bare both while uploading and once sent', () {
    expect(
      chatShowsAsMedia(_message(_file('a.mp4', 0), SendState.pending)),
      isTrue,
    );
    expect(
      chatShowsAsMedia(_message(_file('a.mp4', 7), SendState.sent)),
      isTrue,
    );
  });

  test('any other file stays in a bubble', () {
    expect(
      chatShowsAsMedia(_message(_file('a.pdf', 0), SendState.pending)),
      isFalse,
    );
    expect(
      chatShowsAsMedia(_message(_file('a.pdf', 7), SendState.sent)),
      isFalse,
    );
  });

  test('images are bare, text is not', () {
    expect(
      chatShowsAsMedia(
        _message(
          const ImageContent(fileId: 0, name: 'a.png', size: 1, time: 0),
          SendState.pending,
        ),
      ),
      isTrue,
    );
    expect(
      chatShowsAsMedia(
        _message(const MessageContent.text('hi'), SendState.sent),
      ),
      isFalse,
    );
  });
}
