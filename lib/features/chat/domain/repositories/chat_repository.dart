import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';
import '../entities/chat_user.dart';
import '../value_objects/chat_connection_status.dart';
import '../value_objects/message_content.dart';

/// ZenTao chat for a connected ZenTao account ([accountId] is the WorkNexus
/// account id). Local-first: everything received is written to the local DB
/// and the `watch*` streams read from it.
abstract class ChatRepository {
  Stream<ChatConnectionStatus> watchStatus(String accountId);

  /// Logs in with the account's saved ZenTao password. Safe to call again.
  Future<Result<void>> connect(String accountId);

  Future<void> disconnect(String accountId);

  /// Pins [fingerprint] for the account's chat server and reconnects.
  Future<Result<void>> trustCertificate(String accountId, String fingerprint);

  /// Messages from other people as they arrive live (any account), after
  /// they are stored. History syncs and your own messages are not included.
  Stream<ChatMessage> watchIncoming();

  /// Conversations, most recently active first.
  Stream<List<ChatConversation>> watchConversations(String accountId);

  /// The newest [limit] messages of a chat, oldest first.
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = 50,
  });

  Stream<List<ChatUser>> watchUsers(String accountId);

  /// Fetches the newest page of a chat from the server.
  Future<Result<void>> refreshMessages(String accountId, String chatGid);

  /// Fetches the page before the oldest stored message; returns how many
  /// messages arrived (0 = reached the beginning).
  Future<Result<int>> loadOlderMessages(String accountId, String chatGid);

  /// Shows the message immediately as pending, then sends it — as a reply to
  /// server message [replyToId] when given, as Markdown when [markdown].
  Future<Result<void>> sendText(
    String accountId,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
  });

  /// One message by server id; null until it is stored locally (see
  /// [fetchMessages]).
  Stream<ChatMessage?> watchMessage(
    String accountId,
    String chatGid,
    int serverId,
  );

  /// Every reply stored for a chat, oldest first.
  Stream<List<ChatMessage>> watchReplies(String accountId, String chatGid);

  /// Fetches specific messages (e.g. the parent of a reply) from the server.
  Future<Result<void>> fetchMessages(
    String accountId,
    String chatGid,
    List<int> serverIds,
  );

  /// Uploads a file (images become image messages) and sends it, shown as
  /// pending meanwhile — as a reply to [replyToId] when given.
  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  });

  /// Upload progress (0–1) of a pending file message.
  Stream<double> watchUploadProgress(String messageGid);

  /// Downloads an attachment to a local file and returns its path (for the
  /// video player or opening it with the system's default app).
  Future<Result<String>> attachmentFile(
    String accountId,
    MessageContent content,
  );

  /// A still frame of a video attachment (downloads small videos to make
  /// it). Fails when the video is too large to fetch just for a preview or no
  /// frame can be extracted.
  Future<Result<Uint8List>> videoThumbnail(
    String accountId,
    MessageContent video,
  );

  /// How many members a chat has (`chatGetMembers`).
  Future<Result<int>> memberCount(String accountId, String chatGid);

  /// The signed-in user's id for [accountId] (null until logged in once).
  Stream<int?> watchSelfUserId(String accountId);

  /// The one-to-one chat with [userId], created on the server when it does
  /// not exist yet; returns its gid.
  Future<Result<String>> openDirectChat(String accountId, int userId);

  /// Pins or unpins message [serverId] in [chatGid] (one-to-one chats, or
  /// group owner/admins; the server checks).
  Future<Result<void>> setMessagePinned(
    String accountId,
    String chatGid,
    int serverId, {
    required bool pinned,
  });

  /// Download progress (0–1) of an attachment's original file.
  Stream<double> watchDownloadProgress(
    String accountId,
    MessageContent content,
  );

  /// Whether an attachment's original is already downloaded.
  Future<bool> isAttachmentCached(String accountId, MessageContent content);

  /// User ids of a group's members (unknown users are fetched in the
  /// background and show up through [watchUsers]).
  Future<Result<List<int>>> members(String accountId, String chatGid);

  /// Retracts (unsends) one of the account's own messages.
  Future<Result<void>> retract(String accountId, String messageGid);

  /// Re-sends a message that failed.
  Future<Result<void>> retrySend(String accountId, String messageGid);

  /// Marks everything in the chat as read, locally and on the server.
  Future<Result<void>> markRead(String accountId, String chatGid);

  /// Bytes of an image/file attachment (cached in memory); the server's
  /// smaller preview of an image with [thumbnail] (when it has one).
  Future<Result<Uint8List>> loadAttachment(
    String accountId,
    MessageContent content, {
    bool thumbnail = false,
  });
}
