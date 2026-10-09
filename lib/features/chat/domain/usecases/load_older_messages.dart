import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

/// Makes the messages before the oldest one shown available; returns how
/// many there now are (0 = the start of the conversation).
///
/// Stored ones come first, without asking the server — only those of the
/// timeline, so a lone reply parent or pinned message is not taken for the
/// messages just before. Only when none are
/// stored is the server asked — for the page before [oldestShown], not
/// before the oldest *stored* message: stored history may have gaps
/// (pinned messages and reply parents are fetched by id).
class LoadOlderMessages {
  const LoadOlderMessages(this._repository);

  final ChatRepository _repository;

  ///
  /// In a jump window ([inWindow]) the server is always asked: stored
  /// messages before it need not continue it.
  Future<Result<int>> call({
    required String accountId,
    required String chatGid,
    ChatMessage? oldestShown,
    bool inWindow = false,
  }) async {
    if (oldestShown != null && !inWindow) {
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
      inWindow: inWindow,
    );
  }
}
