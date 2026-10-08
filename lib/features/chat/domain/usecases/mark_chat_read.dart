import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Marks a chat read (when the user has it open).
class MarkChatRead {
  const MarkChatRead(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
  }) => _repository.markRead(accountId, chatGid);
}
