import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Opens the chat session of a ZenTao account (idempotent).
class ConnectChat {
  const ConnectChat(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call(String accountId) => _repository.connect(accountId);
}
