import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';
import '../value_objects/message_content.dart';

/// A preview frame for a video message.
class LoadVideoThumbnail {
  const LoadVideoThumbnail(this._repository);

  final ChatRepository _repository;

  Future<Result<Uint8List>> call({
    required String accountId,
    required MessageContent video,
  }) => _repository.videoThumbnail(accountId, video);
}
