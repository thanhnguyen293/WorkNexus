import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_message.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/fetch_message_attachment.dart';
import 'package:work_nexus/features/chat/domain/value_objects/message_content.dart';

class _Repo extends Mock implements ChatRepository {}

void main() {
  late _Repo repo;
  late List<ChatMessage?> stored;

  const image = MessageContent.image(
    fileId: 5,
    name: 'a.png',
    size: 12,
    time: 1,
    mimeType: 'image/png',
  );

  ChatMessage message(MessageContent content, {bool deleted = false}) =>
      ChatMessage(
        accountId: 'a',
        gid: 'm7',
        chatGid: 'g',
        senderId: 2,
        sentAt: DateTime(2026),
        content: content,
        isMine: false,
        serverId: 7,
        deleted: deleted,
      );

  setUpAll(() => registerFallbackValue(image));

  setUp(() {
    repo = _Repo();
    stored = [];
    // Each look-up returns the next stored state, the last one after.
    when(() => repo.watchMessage(any(), any(), any())).thenAnswer(
      (_) =>
          Stream.value(stored.length > 1 ? stored.removeAt(0) : stored.first),
    );
    when(
      () => repo.fetchMessages(any(), any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => repo.attachmentFile(any(), any()),
    ).thenAnswer((_) async => const Ok('/cache/a.png'));
  });

  Future<Result<dynamic>> run() =>
      FetchMessageAttachment(repo)(accountId: 'a', chatGid: 'g', messageId: 7);

  test('downloads a stored image and describes it', () async {
    stored = [message(image)];

    final result = await run();

    expect(result.valueOrNull, (
      path: '/cache/a.png',
      name: 'a.png',
      size: 12,
      mimeType: 'image/png',
      isImage: true,
    ));
    verify(() => repo.attachmentFile('a', image)).called(1);
    verifyNever(() => repo.fetchMessages(any(), any(), any()));
  });

  test('fetches a message that is not stored yet', () async {
    stored = [
      null,
      message(
        const MessageContent.file(fileId: 6, name: 'r.pdf', size: 9, time: 1),
      ),
    ];

    final result = await run();

    expect((result.valueOrNull as dynamic).isImage, isFalse);
    verify(() => repo.fetchMessages('a', 'g', [7])).called(1);
  });

  test('a message the server does not have is not found', () async {
    stored = [null];

    expect((await run()).failureOrNull, isA<NotFoundFailure>());
  });

  test('refuses a recalled message and one without a file', () async {
    stored = [message(image, deleted: true)];
    expect((await run()).failureOrNull, isA<NotFoundFailure>());

    stored = [message(const MessageContent.text('hi'))];
    expect((await run()).failureOrNull, isA<ValidationFailure>());
    verifyNever(() => repo.attachmentFile(any(), any()));
  });
}
