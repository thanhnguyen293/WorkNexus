import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Fetches a page around a message far back in a chat (a reply's parent),
/// so a jump to it shows it in place instead of paging all the way back;
/// returns the window's index span, or null when it cannot be placed.
class LoadMessagesAround {
  const LoadMessagesAround(this._repository);

  final ChatRepository _repository;

  Future<Result<({int from, int to})?>> call({
    required String accountId,
    required String chatGid,
    required int serverId,
  }) => _repository.loadMessagesAround(accountId, chatGid, serverId);
}
