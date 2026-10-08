import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../../domain/usecases/parse_message_content.dart';
import '../datasources/chat_file_cache.dart';
import '../datasources/chat_local_datasource.dart';
import 'chat_attachment_loader.dart';

/// Reports and frees the disk space of downloaded attachments. Files are
/// named by attachment, not by chat, so which chat a file belongs to comes
/// from the stored messages that reference it.
class ChatCacheManager {
  ChatCacheManager(this._local, this._files, this._attachments, this._parse);

  final ChatLocalDatasource _local;
  final ChatFileCache _files;
  final ChatAttachmentLoader _attachments;
  final ParseMessageContent _parse;

  void setLimit(int bytes) => _files.maxBytes = bytes;

  Future<Result<ChatCacheUsage>> usage() async {
    try {
      final chats = <ChatCacheChatUsage>[];
      for (final accountId in await _local.chatAccountIds()) {
        final sizes = await _files.sizes(accountId);
        if (sizes.isEmpty) continue;
        final perChat = <String, int>{};
        (await _owners(accountId)).forEach((name, cgid) {
          final size = sizes[name];
          if (size != null) perChat[cgid] = (perChat[cgid] ?? 0) + size;
        });
        perChat.forEach(
          (cgid, bytes) => chats.add(
            ChatCacheChatUsage(
              accountId: accountId,
              chatGid: cgid,
              bytes: bytes,
            ),
          ),
        );
      }
      chats.sort((a, b) => b.bytes.compareTo(a.bytes));
      return Ok(
        ChatCacheUsage(
          totalBytes: await _files.totalBytes(),
          limitBytes: _files.maxBytes,
          chats: chats,
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not measure the chat cache', cause: e));
    }
  }

  Future<Result<void>> clear({String? accountId, String? chatGid}) async {
    try {
      if (accountId == null || chatGid == null) {
        await _files.clear();
        _attachments.clearMemory();
        return const Ok(null);
      }
      final owners = await _owners(accountId);
      await _files.delete(accountId, [
        for (final MapEntry(:key, :value) in owners.entries)
          if (value == chatGid) key,
      ]);
      _attachments.clearMemory(accountId: accountId);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not clear the chat cache', cause: e));
    }
  }

  /// On-disk file name → chat gid, for every attachment message stored.
  Future<Map<String, String>> _owners(String accountId) async => {
    for (final m in await _local.attachmentMessages(accountId))
      for (final name in ChatAttachmentLoader.diskNamesOf(
        _parse(m.contentType, m.content),
      ))
        name: m.cgid,
  };
}
