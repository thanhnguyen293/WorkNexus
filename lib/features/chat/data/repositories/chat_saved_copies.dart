import 'dart:io';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/value_objects/message_content.dart';
import '../datasources/chat_local_datasource.dart';
import 'chat_attachment_loader.dart';
import 'chat_session.dart';

/// Copies of attachments the user saved somewhere ("Save as…"), remembered
/// so "Show in folder" opens the copy they chose rather than the app cache.
class ChatSavedCopies {
  ChatSavedCopies(this._local, this._attachments, {required this.now});

  final ChatLocalDatasource _local;
  final ChatAttachmentLoader _attachments;
  final DateTime Function() now;

  /// Copies [content] (downloaded first if needed) to [targetPath].
  Future<Result<void>> saveTo(
    String accountId,
    ChatSession? session,
    MessageContent content,
    String targetPath,
  ) async {
    final String source;
    switch (await _attachments.localFile(accountId, session, content)) {
      case Ok(:final value):
        source = value;
      case Err(:final failure):
        return Err(failure);
    }
    try {
      await File(source).copy(targetPath);
    } on FileSystemException catch (e) {
      return Err(StorageFailure('Could not save the file', cause: e));
    }
    final id = _fileId(content);
    if (id > 0) {
      try {
        await _local.saveSavedFilePath(accountId, id, targetPath, now());
      } on Exception {
        // Saved all the same; "Show in folder" just falls back to the cache.
      }
    }
    return const Ok(null);
  }

  /// The last saved copy of [content], when it is still on disk.
  Future<String?> find(String accountId, MessageContent content) async {
    final id = _fileId(content);
    if (id <= 0) return null;
    try {
      final path = await _local.savedFilePath(accountId, id);
      return path != null && File(path).existsSync() ? path : null;
    } on Exception {
      return null;
    }
  }

  static int _fileId(MessageContent content) => switch (content) {
    ImageContent(:final fileId) || FileContent(:final fileId) => fileId,
    _ => 0,
  };
}
