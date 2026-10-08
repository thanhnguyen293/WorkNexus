import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Pulls the newest messages of a chat from the server (e.g. when it opens).
class RefreshChatMessages {
  const RefreshChatMessages(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
  }) => _repository.refreshMessages(accountId, chatGid);
}
