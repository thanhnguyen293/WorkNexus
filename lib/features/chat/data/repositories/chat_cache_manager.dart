import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../../domain/usecases/parse_message_content.dart';
import '../../domain/value_objects/chat_media_kind.dart';
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
        final perChat = <String, Map<ChatMediaKind, int>>{};
        (await _owners(accountId)).forEach((name, owner) {
          final size = sizes[name];
          if (size == null) return;
          final kinds = perChat.putIfAbsent(owner.cgid, () => {});
          kinds[owner.kind] = (kinds[owner.kind] ?? 0) + size;
        });
        perChat.forEach(
          (cgid, kinds) => chats.add(
            ChatCacheChatUsage(
              accountId: accountId,
              chatGid: cgid,
              bytes: kinds.values.fold(0, (sum, b) => sum + b),
              imageBytes: kinds[ChatMediaKind.image] ?? 0,
              videoBytes: kinds[ChatMediaKind.video] ?? 0,
              fileBytes: kinds[ChatMediaKind.file] ?? 0,
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
          if (value.cgid == chatGid) key,
      ]);
      _attachments.clearMemory(accountId: accountId);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not clear the chat cache', cause: e));
    }
  }

  /// On-disk file name → its chat and kind, for every attachment message
  /// stored.
  Future<Map<String, ({String cgid, ChatMediaKind kind})>> _owners(
    String accountId,
  ) async => {
    for (final m in await _local.attachmentMessages(accountId))
      if (_parse(m.contentType, m.content) case final content)
        if (chatMediaKindOf(content) case final kind?)
          for (final name in ChatAttachmentLoader.diskNamesOf(content))
            name: (cgid: m.cgid, kind: kind),
  };
}
