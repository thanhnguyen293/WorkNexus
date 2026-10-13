import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';
import 'package:work_nexus/features/chat/presentation/widgets/message_body.dart';

ChatMessage _message(MessageContent content, {bool deleted = false}) =>
    ChatMessage(
      accountId: 'zt',
      gid: 'g1',
      chatGid: 'c1',
      senderId: 1,
      sentAt: DateTime(2026, 10, 13),
      content: content,
      isMine: true,
      sendState: SendState.sent,
      deleted: deleted,
    );

void main() {
  test('code and rendered Markdown get the wide bubble', () {
    expect(chatShowsWide(_message(const MessageContent.code('x = 1'))), isTrue);
    expect(
      chatShowsWide(
        _message(const MessageContent.text('**bold**', markdown: true)),
      ),
      isTrue,
    );
    // Plain text that is evidently Markdown renders formatted too.
    expect(
      chatShowsWide(_message(const MessageContent.text('```\ncode\n```'))),
      isTrue,
    );
  });

  test('plain lines and retracted messages keep the normal width', () {
    expect(
      chatShowsWide(_message(const MessageContent.text('hello'))),
      isFalse,
    );
    // Sent as Markdown but without any of its syntax: drawn as plain text.
    expect(
      chatShowsWide(
        _message(const MessageContent.text('hello', markdown: true)),
      ),
      isFalse,
    );
    expect(
      chatShowsWide(
        _message(const MessageContent.code('x = 1'), deleted: true),
      ),
      isFalse,
    );
  });
}
