import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Fetches specific messages by server id — e.g. the original of a reply that
/// is older than what has been loaded.
class FetchChatMessages {
  const FetchChatMessages(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
    required List<int> serverIds,
  }) => _repository.fetchMessages(accountId, chatGid, serverIds);
}
