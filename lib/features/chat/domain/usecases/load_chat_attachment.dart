import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/message_content.dart';

/// Loads the bytes of an image or file sent in chat.
class LoadChatAttachment {
  const LoadChatAttachment(this._repository);

  final ChatRepository _repository;

  Future<Result<Uint8List>> call({
    required String accountId,
    required MessageContent content,
    bool thumbnail = false,
  }) => _repository.loadAttachment(accountId, content, thumbnail: thumbnail);
}
