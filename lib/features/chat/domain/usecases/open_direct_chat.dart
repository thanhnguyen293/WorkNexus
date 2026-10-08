import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// The one-to-one chat with a user (created when needed); returns its gid.
class OpenDirectChat {
  const OpenDirectChat(this._repository);

  final ChatRepository _repository;

  Future<Result<String>> call({
    required String accountId,
    required int userId,
  }) => _repository.openDirectChat(accountId, userId);
}
