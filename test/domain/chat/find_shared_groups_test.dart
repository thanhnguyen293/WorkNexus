import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/error/failure.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/chat/domain/entities/chat_conversation.dart';
import 'package:work_nexus/features/chat/domain/repositories/chat_repository.dart';
import 'package:work_nexus/features/chat/domain/usecases/find_shared_groups.dart';

class _Repo extends Mock implements ChatRepository {}

ChatConversation _chat(
  String gid, {
  ChatType type = ChatType.group,
  bool archived = false,
  int? activeDay,
}) => ChatConversation(
  accountId: 'a',
  gid: gid,
  type: type,
  name: gid,
  archived: archived,
  lastActiveAt: activeDay == null ? null : DateTime(2026, 1, activeDay),
);

void main() {
  late _Repo repo;

  setUp(() => repo = _Repo());

  void members(String gid, Result<List<int>> reply) =>
      when(() => repo.members('a', gid)).thenAnswer((_) async => reply);

  test('keeps live groups that have the user, newest first', () async {
    when(() => repo.watchConversations('a')).thenAnswer(
      (_) => Stream.value([
        _chat('old', activeDay: 1),
        _chat('new', activeDay: 9),
        _chat('without', activeDay: 5),
        _chat('archived', archived: true),
        _chat('1&7', type: ChatType.one2one),
      ]),
    );
    members('old', const Ok([1, 7]));
    members('new', const Ok([7, 3]));
    members('without', const Ok([1, 3]));

    final result = await FindSharedGroups(repo, parallel: 2)('a', 7);

    expect(result.valueOrNull?.map((c) => c.gid), ['new', 'old']);
    verifyNever(() => repo.members('a', 'archived'));
    verifyNever(() => repo.members('a', '1&7'));
  });

  test('skips a group that fails while others answer', () async {
    when(
      () => repo.watchConversations('a'),
    ).thenAnswer((_) => Stream.value([_chat('down'), _chat('up')]));
    members('down', const Err(NetworkFailure('timeout')));
    members('up', const Ok([7]));

    final result = await FindSharedGroups(repo)('a', 7);

    expect(result.valueOrNull?.map((c) => c.gid), ['up']);
  });

  test('fails when no group answers', () async {
    when(
      () => repo.watchConversations('a'),
    ).thenAnswer((_) => Stream.value([_chat('g')]));
    members('g', const Err(NetworkFailure('Chat is offline')));

    final result = await FindSharedGroups(repo)('a', 7);

    expect(result, isA<Err<List<ChatConversation>>>());
  });

  test('no groups is an empty answer, not a failure', () async {
    when(
      () => repo.watchConversations('a'),
    ).thenAnswer((_) => Stream.value(const []));

    expect((await FindSharedGroups(repo)('a', 7)).valueOrNull, isEmpty);
  });
}
