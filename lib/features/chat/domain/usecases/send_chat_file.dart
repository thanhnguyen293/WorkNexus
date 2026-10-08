import 'dart:typed_data';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../repositories/chat_repository.dart';

/// Sends a file or image (pasted, dropped or picked). Empty files are
/// rejected, as the server would refuse them.
class SendChatFile {
  const SendChatFile(this._repository);

  final ChatRepository _repository;

  Future<Result<void>> call({
    required String accountId,
    required String chatGid,
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  }) async {
    if (bytes.isEmpty) {
      return const Err(UnexpectedFailure('Cannot send an empty file'));
    }
    return _repository.sendFile(
      accountId,
      chatGid,
      name: name.trim().isEmpty ? 'file' : name.trim(),
      bytes: bytes,
      mimeType: mimeType,
      replyToId: replyToId,
    );
  }
}
