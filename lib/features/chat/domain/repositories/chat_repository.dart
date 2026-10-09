import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/chat_cache_usage.dart';
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

  /// The newest [limit] messages of a chat's timeline, oldest first —
  /// without messages stored on their own (reply parents, pinned ones, jump
  /// windows) that no page has joined to it yet.
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = 50,
  });

  Stream<List<ChatUser>> watchUsers(String accountId);

  /// Fetches the newest page of a chat from the server.
  Future<Result<void>> refreshMessages(String accountId, String chatGid);

  /// The stored messages with an index in [fromIndex]–[toIndex] (a jump
  /// window), oldest first.
  Stream<List<ChatMessage>> watchMessagesInRange(
    String accountId,
    String chatGid, {
    required int fromIndex,
    required int toIndex,
  });

  /// Fetches the page before the oldest stored message; returns how many
  /// messages arrived (0 = reached the beginning). [inWindow]: the page
  /// extends a jump window rather than the timeline.
  Future<Result<int>> loadOlderMessages(
    String accountId,
    String chatGid, {
    int? beforeServerId,
    bool inWindow = false,
  });

  /// Fetches the pages around server message [serverId] as a jump window;
  /// returns its index span, or null when it cannot be placed.
  Future<Result<({int from, int to})?>> loadMessagesAround(
    String accountId,
    String chatGid,
    int serverId,
  );

  /// Fetches the page after server message [afterServerId] into a jump
  /// window; returns how many newer messages arrived (0 = the newest).
  Future<Result<int>> loadNewerMessages(
    String accountId,
    String chatGid, {
    required int afterServerId,
  });

  /// Joins jump window [fromIndex]–[toIndex] to the timeline when it reaches
  /// it; returns how many timeline messages there then are from [fromIndex]
  /// on, or null when it does not reach it.
  Future<Result<int?>> joinWindowToTimeline(
    String accountId,
    String chatGid, {
    required int fromIndex,
    required int toIndex,
  });

  /// How many messages of [chatGid] are stored locally from before [before].
  Future<Result<int>> countOlderMessages(
    String accountId,
    String chatGid, {
    required DateTime before,
  });

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

  /// Sends one emoji shown large; [code] is its wire form (`:thumbsup:`).
  Future<Result<void>> sendEmoji(String accountId, String chatGid, String code);

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

  /// The server's role names by role code (`dev` → its name, and roles an
  /// admin added), as the official client shows them.
  Future<Result<Map<String, String>>> roleNames(String accountId);

  /// Stops downloading an attachment; [attachmentFile] then fails with a
  /// `CancelledFailure`.
  void cancelDownload(String accountId, MessageContent content);

  /// A still frame of a video attachment (downloads small videos to make
  /// it). Fails when the video is too large to fetch just for a preview or no
  /// frame can be extracted.
  /// Length of a video that is already downloaded (it is not downloaded
  /// just for this).
  Future<Result<Duration>> videoDuration(
    String accountId,
    MessageContent video,
  );

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

  /// Fetches every user of the server (for picking people to chat with).
  Future<Result<void>> refreshUsers(String accountId);

  /// Creates a group chat named [name] with [memberIds] (the signed-in user
  /// is added); returns its gid.
  Future<Result<String>> createGroupChat(
    String accountId, {
    required String name,
    required List<int> memberIds,
  });

  /// Sets a group's picture: an uploaded [image] (PNG/JPEG), or [text] on
  /// [color] (`#RRGGBB`).
  Future<Result<void>> setGroupAvatar(
    String accountId,
    String chatGid, {
    String? text,
    String? color,
    Uint8List? image,
  });

  /// Sets the signed-in user's own picture from [image] (any common image
  /// format; cut to its centred square), then reloads users so it shows.
  Future<Result<void>> setMyAvatar(String accountId, Uint8List image);

  /// Pins or unpins [chatGid] at the top of the chat list (synced with the
  /// server, so other clients see it too).
  Future<Result<void>> setChatStarred(
    String accountId,
    String chatGid, {
    required bool starred,
  });

  /// Mutes or unmutes [chatGid]: no desktop notifications for it. Local only —
  /// the server has no such setting.
  Future<Result<void>> setChatMuted(
    String accountId,
    String chatGid, {
    required bool muted,
  });

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

  /// A chat's image and file messages stored locally, newest first.
  Stream<List<ChatMessage>> watchAttachments(String accountId, String chatGid);

  /// Disk space used by downloaded attachments, per chat.
  Future<Result<ChatCacheUsage>> cacheUsage();

  /// Deletes downloaded attachments: of one chat, or all of them when
  /// [chatGid] is null. Messages are kept; files download again on demand.
  Future<Result<void>> clearCache({String? accountId, String? chatGid});

  /// The most disk space attachments may use; older ones are dropped first.
  void setCacheLimit(int bytes);

  /// Largest video (bytes) downloaded on its own for its preview frame; 0
  /// downloads none until clicked.
  void setVideoAutoDownloadLimit(int bytes);

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
