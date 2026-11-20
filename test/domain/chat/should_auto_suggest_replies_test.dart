import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/usecases/should_auto_suggest_replies.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

final _now = DateTime(2026, 11, 20, 10);

ChatMessage _message(
  String text, {
  Duration ago = const Duration(seconds: 30),
  bool mine = false,
  bool notice = false,
  String gid = 'm1',
}) => ChatMessage(
  accountId: 'a',
  gid: gid,
  chatGid: 'c',
  senderId: mine ? 1 : 2,
  sentAt: _now.subtract(ago),
  content: MessageContent.text(text),
  isMine: mine,
  isNotice: notice,
);

void main() {
  const decide = ShouldAutoSuggestReplies();
  final opened = _now.subtract(const Duration(minutes: 1));

  AutoReplyDecision run(
    ChatMessage? latest, {
    bool draftEmpty = true,
    DateTime? openedAt,
    String? handledGid,
    DateTime? lastRunInChat,
    int runsLastHour = 0,
  }) => decide(
    latest: latest,
    draftEmpty: draftEmpty,
    now: _now,
    openedAt: openedAt ?? opened,
    handledGid: handledGid,
    lastRunInChat: lastRunInChat,
    runsLastHour: runsLastHour,
  );

  test('runs for a quiet chat whose last message asks something', () {
    expect(
      run(_message('Anh review giúp em MR này nhé?')),
      isA<AutoReplyRun>(),
    );
  });

  test('waits until the chat has been quiet for 10 seconds', () {
    final decision = run(
      _message('Còn bug login thì sao?', ago: const Duration(seconds: 3)),
    );
    expect(decision, isA<AutoReplyWait>());
    expect((decision as AutoReplyWait).wait, const Duration(seconds: 7));
  });

  test('a chat just opened waits to settle, then runs', () {
    final decision = run(
      _message('Deploy xong chưa?'),
      openedAt: _now.subtract(const Duration(milliseconds: 500)),
    );
    expect((decision as AutoReplyWait).wait, const Duration(seconds: 1));
  });

  test('waits out the per-chat cooldown', () {
    final decision = run(
      _message('Thêm cái này nữa nhé'),
      lastRunInChat: _now.subtract(const Duration(seconds: 60)),
    );
    expect((decision as AutoReplyWait).wait, const Duration(seconds: 30));
  });

  group('skips', () {
    test('no message, own message or a notice', () {
      expect(run(null), isA<AutoReplySkip>());
      expect(run(_message('Ai rảnh không?', mine: true)), isA<AutoReplySkip>());
      expect(run(_message('X joined', notice: true)), isA<AutoReplySkip>());
    });

    test('a message already answered', () {
      expect(
        run(_message('Họp lúc mấy giờ?'), handledGid: 'm1'),
        isA<AutoReplySkip>(),
      );
    });

    test('while something is typed', () {
      expect(
        run(_message('Họp lúc mấy giờ?'), draftEmpty: false),
        isA<AutoReplySkip>(),
      );
    });

    test('a last message older than 6 hours', () {
      expect(
        run(_message('Họp lúc mấy giờ?', ago: const Duration(hours: 7))),
        isA<AutoReplySkip>(),
      );
    });

    test('once the hourly limit is reached', () {
      expect(
        run(_message('Họp lúc mấy giờ?'), runsLastHour: 20),
        isA<AutoReplySkip>(),
      );
    });

    test('acknowledgements and emoji-only text', () {
      for (final text in ['ok', 'Ok nhé!', 'dạ', 'Cảm ơn', '👍', '1', '=))']) {
        expect(run(_message(text)), isA<AutoReplySkip>(), reason: text);
      }
    });

    test('non-text messages', () {
      expect(
        ShouldAutoSuggestReplies.worthAnswering(
          const MessageContent.emoji('😂'),
        ),
        isFalse,
      );
    });
  });
}
