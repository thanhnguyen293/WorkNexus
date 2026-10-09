import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/usecases/should_notify_chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

ChatMessage _message({bool mine = false}) => ChatMessage(
  accountId: 'acc',
  gid: 'm1',
  chatGid: 'g1',
  senderId: 31,
  sentAt: DateTime(2026),
  content: const MessageContent.text('hi'),
  isMine: mine,
);

void main() {
  const notify = ShouldNotifyChatMessage();
  const open = (accountId: 'acc', chatGid: 'g1');
  const other = (accountId: 'acc', chatGid: 'g2');

  test('stays quiet for the chat open in the focused window', () {
    expect(
      notify(_message(), enabled: true, appFocused: true, visibleChat: open),
      isFalse,
    );
  });

  test('notifies when the window is in the back or another chat is open', () {
    expect(
      notify(_message(), enabled: true, appFocused: false, visibleChat: open),
      isTrue,
    );
    expect(
      notify(_message(), enabled: true, appFocused: true, visibleChat: other),
      isTrue,
    );
  });

  test('whileViewing notifies even for the chat being looked at', () {
    expect(
      notify(
        _message(),
        enabled: true,
        appFocused: true,
        visibleChat: open,
        whileViewing: true,
      ),
      isTrue,
    );
  });

  test('whileViewing never overrides off, own messages', () {
    expect(
      notify(
        _message(),
        enabled: false,
        appFocused: false,
        visibleChat: null,
        whileViewing: true,
      ),
      isFalse,
    );
    expect(
      notify(
        _message(mine: true),
        enabled: true,
        appFocused: false,
        visibleChat: null,
        whileViewing: true,
      ),
      isFalse,
    );
  });
}
