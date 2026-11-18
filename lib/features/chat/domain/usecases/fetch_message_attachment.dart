import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_local_api.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/message_content.dart';

/// Downloads the file or image of one message to a local file — for a local
/// AI tool that reads the stored history, where attachments are only named.
/// A message not stored yet is fetched from the server first.
class FetchMessageAttachment {
  const FetchMessageAttachment(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatAttachmentFile>> call({
    required String accountId,
    required String chatGid,
    required int messageId,
  }) async {
    var message = await _stored(accountId, chatGid, messageId);
    if (message == null) {
      final fetched = await _repository.fetchMessages(accountId, chatGid, [
        messageId,
      ]);
      if (fetched case Err(:final failure)) return Err(failure);
      message = await _stored(accountId, chatGid, messageId);
    }
    if (message == null) {
      return Err(NotFoundFailure('Message $messageId not found in this chat'));
    }
    if (message.deleted) {
      return Err(NotFoundFailure('Message $messageId was recalled'));
    }
    final content = message.content;
    final ({String name, int size, String? mimeType, bool isImage}) meta;
    switch (content) {
      case ImageContent(:final name, :final size, :final mimeType):
        meta = (name: name, size: size, mimeType: mimeType, isImage: true);
      case FileContent(:final name, :final size, :final mimeType):
        meta = (name: name, size: size, mimeType: mimeType, isImage: false);
      default:
        return Err(
          ValidationFailure('Message $messageId has no file or image'),
        );
    }
    return switch (await _repository.attachmentFile(accountId, content)) {
      Ok(:final value) => Ok((
        path: value,
        name: meta.name,
        size: meta.size,
        mimeType: meta.mimeType,
        isImage: meta.isImage,
      )),
      Err(:final failure) => Err(failure),
    };
  }

  Future<ChatMessage?> _stored(
    String accountId,
    String chatGid,
    int messageId,
  ) => _repository.watchMessage(accountId, chatGid, messageId).first;
}
