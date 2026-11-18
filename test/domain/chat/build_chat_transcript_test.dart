import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/usecases/build_chat_transcript.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

import 'chat_ai_test_support.dart';

void main() {
  const build = BuildChatTranscript();

  test('writes messages oldest first with time and sender', () {
    final result = build(
      [
        chatText('second', minute: 5, sender: 3),
        chatText('first', minute: 1),
        chatText('mine', minute: 9, mine: true, sender: 1),
      ],
      nameOf: chatName,
      selfName: 'An',
    );

    expect(result.count, 3);
    expect(
      result.text,
      '[18/11 09:01] Lan: first\n'
      '[18/11 09:05] Minh: second\n'
      '[18/11 09:09] An: mine',
    );
  });

  test('turns mentions into names and line breaks into spaces', () {
    final result = build(
      [chatText('hi [@Minh](@#3),\nsee this')],
      nameOf: chatName,
      selfName: 'An',
    );
    expect(result.text, endsWith('Lan: hi @Minh, see this'));
  });

  test('leaves out deleted messages and notices, names attachments', () {
    final result = build(
      [
        chatText('gone', deleted: true),
        chatText('Lan joined', notice: true, minute: 1),
        chatText(
          '',
          minute: 2,
          content: const ImageContent(
            fileId: 1,
            name: 'a.png',
            size: 1,
            time: 1,
          ),
        ),
        chatText(
          '',
          minute: 3,
          content: const FileContent(
            fileId: 2,
            name: 'spec.pdf',
            size: 1,
            time: 1,
          ),
        ),
        chatText(
          '',
          minute: 4,
          content: const UnsupportedContent('conference'),
        ),
      ],
      nameOf: chatName,
      selfName: 'An',
    );
    expect(result.count, 2);
    expect(result.text, contains('Lan: [image]'));
    expect(result.text, contains('Lan: [file: spec.pdf]'));
  });

  test('marks who a reply answers', () {
    final result = build(
      [
        chatText('question', serverId: 10, sender: 3),
        chatText('answer', minute: 1, replyTo: 10),
      ],
      nameOf: chatName,
      selfName: 'An',
    );
    expect(result.text, contains('Lan (↪ Minh): answer'));
  });

  test('drops the oldest messages past the size limit and clips long ones', () {
    const small = BuildChatTranscript(maxChars: 70, maxMessageChars: 10);
    final result = small(
      [
        chatText('oldest message', minute: 1),
        chatText('middle message', minute: 2),
        chatText('newest message', minute: 3),
      ],
      nameOf: chatName,
      selfName: 'An',
    );
    expect(result.count, 2);
    expect(result.text, isNot(contains('oldest')));
    expect(result.text, contains('newest mes…'));
  });
}
