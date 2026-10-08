import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// Makes the messages before the oldest one shown available; returns how
/// many there now are (0 = the start of the conversation).
///
/// Stored ones come first, without asking the server. Only when none are
/// stored is the server asked — for the page before [oldestShown], not
/// before the oldest *stored* message: stored history may have gaps
/// (pinned messages and reply parents are fetched by id).
class LoadOlderMessages {
  const LoadOlderMessages(this._repository);

  final ChatRepository _repository;

  Future<Result<int>> call({
    required String accountId,
    required String chatGid,
    ChatMessage? oldestShown,
  }) async {
    if (oldestShown != null) {
      final stored = await _repository.countOlderMessages(
        accountId,
        chatGid,
        before: oldestShown.sentAt,
      );
      switch (stored) {
        case Ok(:final value) when value > 0:
          return Ok(value);
        case Err(:final failure):
          return Err(failure);
        case Ok():
          break;
      }
    }
    return _repository.loadOlderMessages(
      accountId,
      chatGid,
      beforeServerId: oldestShown?.serverId,
    );
  }
}
