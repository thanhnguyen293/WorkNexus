import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Loads the page of messages before the oldest one shown; returns how many
/// arrived (0 = the start of the conversation).
class LoadOlderMessages {
  const LoadOlderMessages(this._repository);

  final ChatRepository _repository;

  Future<Result<int>> call({
    required String accountId,
    required String chatGid,
  }) => _repository.loadOlderMessages(accountId, chatGid);
}
