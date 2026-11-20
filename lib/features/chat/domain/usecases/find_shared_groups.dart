import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../repositories/chat_repository.dart';

/// The group chats the signed-in user shares with user [userId], most
/// recently active first.
///
/// xxd keeps no membership locally, so each group's members are asked of the
/// server, a few at a time. A group that fails to answer is skipped; only when
/// every group fails is the failure returned.
class FindSharedGroups {
  const FindSharedGroups(this._repository, {this.parallel = 6});

  final ChatRepository _repository;

  /// How many member lists are asked for at once.
  final int parallel;

  Future<Result<List<ChatConversation>>> call(
    String accountId,
    int userId,
  ) async {
    final conversations = await _repository.watchConversations(accountId).first;
    final groups = [
      for (final c in conversations)
        if (c.type == ChatType.group && !c.archived) c,
    ];
    final shared = <ChatConversation>[];
    Failure? failure;
    var answered = 0;
    for (var i = 0; i < groups.length; i += parallel) {
      final batch = groups.skip(i).take(parallel).toList();
      final replies = await Future.wait(
        batch.map((g) => _repository.members(accountId, g.gid)),
      );
      for (final (index, reply) in replies.indexed) {
        switch (reply) {
          case Ok(:final value):
            answered++;
            if (value.contains(userId)) shared.add(batch[index]);
          case Err(failure: final f):
            failure ??= f;
        }
      }
    }
    if (answered == 0 && failure != null) return Err(failure);
    shared.sort(
      (a, b) => (b.lastActiveAt ?? DateTime(0)).compareTo(
        a.lastActiveAt ?? DateTime(0),
      ),
    );
    return Ok(shared);
  }
}
