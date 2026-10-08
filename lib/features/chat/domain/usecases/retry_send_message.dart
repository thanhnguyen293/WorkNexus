import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Re-sends a message whose send failed.
class RetrySendMessage {
  const RetrySendMessage(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String messageGid,
  }) => _repository.retrySend(accountId, messageGid);
}
