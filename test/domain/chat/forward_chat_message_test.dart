import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/forward_chat_message.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class _Repo extends Mock implements ChatRepository {}

ChatMessage _message({
  MessageContent content = const MessageContent.text('hi'),
  int? serverId = 9,
  SendState state = SendState.sent,
  bool deleted = false,
  bool isNotice = false,
}) => ChatMessage(
  accountId: 'a',
  gid: 'm1',
  serverId: serverId,
  chatGid: 'from',
  senderId: 1,
  sentAt: DateTime(2026, 10, 13),
  content: content,
  isMine: false,
  sendState: state,
  deleted: deleted,
  isNotice: isNotice,
);

void main() {
  late _Repo repo;
  late ForwardChatMessage forward;

  setUp(() {
    repo = _Repo();
    forward = ForwardChatMessage(repo);
  });

  test('forwards sent text, code, images and files', () {
    expect(forward.canForward(_message()), isTrue);
    expect(
      forward.canForward(_message(content: const MessageContent.code('x'))),
      isTrue,
    );
    expect(
      forward.canForward(
        _message(
          content: const FileContent(
            fileId: 3,
            name: 'a.pdf',
            size: 1,
            time: 0,
          ),
        ),
      ),
      isTrue,
    );
  });

  test('not a pending, retracted, notice or unreadable message', () {
    expect(forward.canForward(_message(serverId: null)), isFalse);
    expect(forward.canForward(_message(state: SendState.failed)), isFalse);
    expect(forward.canForward(_message(deleted: true)), isFalse);
    expect(forward.canForward(_message(isNotice: true)), isFalse);
    expect(
      forward.canForward(
        _message(content: const MessageContent.unsupported('vote')),
      ),
      isFalse,
    );
  });

  test('sends to every picked chat, even past a failing one', () async {
    when(
      () => repo.forwardMessage('a', 'm1', 'c1'),
    ).thenAnswer((_) async => const Err(NetworkFailure('offline')));
    when(
      () => repo.forwardMessage('a', 'm1', 'c2'),
    ).thenAnswer((_) async => const Ok(null));

    final result = await forward(_message(), toChatGids: ['c1', 'c2']);

    expect(result, isA<Err<void>>());
    verify(() => repo.forwardMessage('a', 'm1', 'c1')).called(1);
    verify(() => repo.forwardMessage('a', 'm1', 'c2')).called(1);
  });

  test('refuses with no chat picked, or a message it cannot forward', () async {
    expect(await forward(_message(), toChatGids: []), isA<Err<void>>());
    expect(
      await forward(_message(deleted: true), toChatGids: ['c1']),
      isA<Err<void>>(),
    );
    verifyNever(() => repo.forwardMessage(any(), any(), any()));
  });
}
