import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Sends a text message. Surrounding whitespace is trimmed; a blank message is
/// rejected rather than sent.
class SendTextMessage {
  const SendTextMessage(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const Err(UnexpectedFailure('Cannot send an empty message'));
    }
    return _repository.sendText(accountId, chatGid, trimmed);
  }
}
