import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_cache_usage.freezed.dart';

/// Disk space used by downloaded chat attachments.
@freezed
abstract class ChatCacheUsage with _$ChatCacheUsage {
  const ChatCacheUsage._();

  const factory ChatCacheUsage({
    required int totalBytes,
    required int limitBytes,

    /// Per chat, largest first. Files whose message is not stored locally
    /// (or of removed accounts) are only in [otherBytes].
    @Default(<ChatCacheChatUsage>[]) List<ChatCacheChatUsage> chats,
  }) = _ChatCacheUsage;

  int get otherBytes =>
      totalBytes - chats.fold<int>(0, (sum, c) => sum + c.bytes);
}

/// The attachments of one chat on disk.
@freezed
abstract class ChatCacheChatUsage with _$ChatCacheChatUsage {
  const factory ChatCacheChatUsage({
    required String accountId,
    required String chatGid,
    required int bytes,
  }) = _ChatCacheChatUsage;
}
