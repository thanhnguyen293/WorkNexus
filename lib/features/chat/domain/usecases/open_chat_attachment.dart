import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/message_content.dart';

/// Makes an attachment available as a local file (to play or open).
class OpenChatAttachment {
  const OpenChatAttachment(this._repository);

  final ChatRepository _repository;

  Future<Result<String>> call({
    required String accountId,
    required MessageContent content,
  }) => _repository.attachmentFile(accountId, content);
}
