import 'dart:typed_data';

import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/usecases/can_send_to_chat.dart';
import '../../domain/usecases/connect_chat.dart';
import '../../domain/usecases/create_group_chat.dart';
import '../../domain/usecases/encode_mentions.dart';
import '../../domain/usecases/fetch_chat_messages.dart';
import '../../domain/usecases/find_linked_ticket.dart';
import '../../domain/usecases/load_chat_attachment.dart';
import '../../domain/usecases/load_messages_around.dart';
import '../../domain/usecases/load_newer_messages.dart';
import '../../domain/usecases/load_older_messages.dart';
import '../../domain/usecases/load_video_thumbnail.dart';
import '../../domain/usecases/mark_chat_read.dart';
import '../../domain/usecases/open_chat_attachment.dart';
import '../../domain/usecases/open_direct_chat.dart';
import '../../domain/usecases/pin_chat_message.dart';
import '../../domain/usecases/refresh_chat_messages.dart';
import '../../domain/usecases/retract_message.dart';
import '../../domain/usecases/retry_send_message.dart';
import '../../domain/usecases/send_chat_file.dart';
import '../../domain/usecases/send_sticker.dart';
import '../../domain/usecases/send_text_message.dart';
import '../../domain/usecases/should_notify_chat_message.dart';
import '../../domain/usecases/trust_chat_certificate.dart';
import '../../domain/value_objects/chat_presence.dart';
import '../../domain/value_objects/message_content.dart';

/// The chat view's commands. Each delegates to one use case; widgets show the
/// returned [Result] (CLAUDE.md 2.4, 11.3).
class ChatController {
  ChatController(ChatRepository repository)
    : _repository = repository,
      _connect = ConnectChat(repository),
      _trust = TrustChatCertificate(repository),
      _send = SendTextMessage(repository),
      _retry = RetrySendMessage(repository),
      _refresh = RefreshChatMessages(repository),
      _older = LoadOlderMessages(repository),
      _newer = LoadNewerMessages(repository),
      _around = LoadMessagesAround(repository),
      _markRead = MarkChatRead(repository),
      _attachment = LoadChatAttachment(repository),
      _fetch = FetchChatMessages(repository),
      _sendFile = SendChatFile(repository),
      _retract = RetractMessage(repository),
      _open = OpenChatAttachment(repository),
      _thumbnail = LoadVideoThumbnail(repository),
      _pin = PinChatMessage(repository),
      _direct = OpenDirectChat(repository);

  static const pageSize = 50;

  final ConnectChat _connect;
  final TrustChatCertificate _trust;
  final SendTextMessage _send;
  final RetrySendMessage _retry;
  final RefreshChatMessages _refresh;
  final LoadOlderMessages _older;
  final LoadNewerMessages _newer;
  final LoadMessagesAround _around;
  final MarkChatRead _markRead;
  final LoadChatAttachment _attachment;
  final FetchChatMessages _fetch;
  final SendChatFile _sendFile;
  final RetractMessage _retract;
  final OpenChatAttachment _open;
  final LoadVideoThumbnail _thumbnail;
  final PinChatMessage _pin;
  final OpenDirectChat _direct;
  final _threads = const BuildReplyThread();
  final _shouldNotify = const ShouldNotifyChatMessage();
  final _canSend = const CanSendToChat();
  final ChatRepository _repository;

  Future<Result<void>> connect(String accountId) => _connect(accountId);

  /// Drops the session and signs in again, so the server sends the chat
  /// list afresh (after the local copy was cleared).
  Future<Result<void>> reconnect(String accountId) async {
    await _repository.disconnect(accountId);
    return _connect(accountId);
  }

  bool canPin(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) => _pin.canPin(chat, selfUserId: selfUserId, selfAccount: selfAccount);

  bool canSend(
    ChatConversation chat, {
    required int? selfUserId,
    required String? selfAccount,
  }) => _canSend(chat, selfUserId: selfUserId, selfAccount: selfAccount);

  /// Mutes or unmutes a chat's notifications (a CRUD pass-through).
  Future<Result<void>> setChatMuted(
    ChatConversation chat, {
    required bool muted,
  }) => _repository.setChatMuted(chat.accountId, chat.gid, muted: muted);

  /// Sets your own presence (a CRUD pass-through).
  Future<Result<void>> setMyPresence(String accountId, ChatPresence presence) =>
      _repository.setMyPresence(accountId, presence);

  /// Pins or unpins a chat at the top of the list (a CRUD pass-through).
  Future<Result<void>> setChatStarred(
    ChatConversation chat, {
    required bool starred,
  }) => _repository.setChatStarred(chat.accountId, chat.gid, starred: starred);

  Future<Result<void>> setPinned(ChatMessage message, {required bool pinned}) =>
      _pin(message, pinned: pinned);

  Future<Result<String>> openDirectChat(String accountId, int userId) =>
      _direct(accountId: accountId, userId: userId);

  Future<Result<String>> createGroupChat(
    String accountId, {
    required String name,
    required List<int> memberIds,
  }) => CreateGroupChat(_repository)(
    accountId: accountId,
    name: name,
    memberIds: memberIds,
  );

  /// Sets a group's picture (pass-through; CLAUDE.md 2.4).
  Future<Result<void>> setGroupAvatar(
    String accountId,
    String chatGid, {
    String? text,
    String? color,
    Uint8List? image,
  }) => _repository.setGroupAvatar(
    accountId,
    chatGid,
    text: text,
    color: color,
    image: image,
  );

  /// Sets the user's own picture (pass-through; CLAUDE.md 2.4).
  Future<Result<void>> setMyAvatar(String accountId, Uint8List image) =>
      _repository.setMyAvatar(accountId, image);

  /// Loads every user of the server (pass-through; CLAUDE.md 2.4).
  Future<Result<void>> refreshUsers(String accountId) =>
      _repository.refreshUsers(accountId);

  void setCacheLimit(int bytes) => _repository.setCacheLimit(bytes);
  void setVideoAutoDownloadLimit(int bytes) =>
      _repository.setVideoAutoDownloadLimit(bytes);

  /// Deletes downloaded attachments of one chat, or all when [chatGid] is
  /// null (a pass-through; CLAUDE.md 2.4).
  Future<Result<void>> clearCache({String? accountId, String? chatGid}) =>
      _repository.clearCache(accountId: accountId, chatGid: chatGid);

  /// The synced ZenTao ticket [url] points to, if any.
  Ticket? linkedTicket(String url, List<Ticket> tickets) =>
      const FindLinkedTicket()(url, tickets);

  /// Live messages from others; a pass-through stream (CLAUDE.md 2.4).
  Stream<ChatMessage> watchIncoming() => _repository.watchIncoming();

  bool shouldNotify(
    ChatMessage message, {
    required bool enabled,
    required bool appFocused,
    required ({String accountId, String chatGid})? visibleChat,
    ChatConversation? conversation,
    bool whileViewing = false,
  }) => _shouldNotify(
    message,
    enabled: enabled,
    appFocused: appFocused,
    visibleChat: visibleChat,
    conversation: conversation,
    whileViewing: whileViewing,
  );

  Future<Result<void>> trust(String accountId, String fingerprint) =>
      _trust(accountId: accountId, fingerprint: fingerprint);

  /// Sends [text]; the `@Name` mentions in [mentions] (name → user id) are
  /// encoded as xxd mention markup first.
  Future<Result<void>> send(
    String accountId,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
    Map<String, int> mentions = const {},
  }) => _send(
    accountId: accountId,
    chatGid: chatGid,
    text: const EncodeMentions()(text, mentions),
    replyToId: replyToId,
    markdown: markdown,
  );

  /// Sends [emoji] alone, shown large without a bubble (e.g. a like).
  Future<Result<void>> sendLargeEmoji(
    String accountId,
    String chatGid,
    String emoji,
  ) => SendLargeEmoji(_repository)(
    accountId: accountId,
    chatGid: chatGid,
    emoji: emoji,
  );

  Future<Result<void>> fetchMessages(
    String accountId,
    String chatGid,
    List<int> serverIds,
  ) => _fetch(accountId: accountId, chatGid: chatGid, serverIds: serverIds);

  Future<Result<void>> retry(String accountId, String messageGid) =>
      _retry(accountId: accountId, messageGid: messageGid);

  Future<Result<void>> refresh(String accountId, String chatGid) =>
      _refresh(accountId: accountId, chatGid: chatGid);

  /// See [LoadOlderMessages]: how many messages before [oldestShown] are
  /// now available to show.
  Future<Result<int>> loadOlder(
    String accountId,
    String chatGid, {
    ChatMessage? oldestShown,
    bool inWindow = false,
  }) => _older(
    accountId: accountId,
    chatGid: chatGid,
    oldestShown: oldestShown,
    inWindow: inWindow,
  );

  /// See [LoadNewerMessages]: extends a jump window towards the newest
  /// message, joining it to the timeline at the end.
  Future<Result<NewerMessages>> loadNewer(
    String accountId,
    String chatGid, {
    required ChatMessage newestShown,
    required int windowFrom,
  }) => _newer(
    accountId: accountId,
    chatGid: chatGid,
    newestShown: newestShown,
    windowFrom: windowFrom,
  );

  /// See [LoadMessagesAround]: a jump window around message [serverId].
  Future<Result<({int from, int to})?>> loadAround(
    String accountId,
    String chatGid,
    int serverId,
  ) => _around(accountId: accountId, chatGid: chatGid, serverId: serverId);

  Future<Result<void>> markRead(String accountId, String chatGid) =>
      _markRead(accountId: accountId, chatGid: chatGid);

  Future<Result<Uint8List>> loadAttachment(
    String accountId,
    MessageContent content, {
    bool thumbnail = false,
  }) =>
      _attachment(accountId: accountId, content: content, thumbnail: thumbnail);

  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  }) => _sendFile(
    accountId: accountId,
    chatGid: chatGid,
    name: name,
    bytes: bytes,
    mimeType: mimeType,
    replyToId: replyToId,
  );

  bool canRetract(ChatMessage message) => _retract.canRetract(message);

  Future<Result<void>> retract(ChatMessage message) => _retract(message);

  /// The thread [messageId] belongs to (its root and every reply).
  ReplyThread thread(int messageId, List<ChatMessage> replies) =>
      _threads(messageId, replies);

  Map<int, int> replyCounts(List<ChatMessage> replies) =>
      _threads.countsByRoot(replies);

  Map<int, ThreadSummary> threadSummaries(List<ChatMessage> replies) =>
      _threads.summariesByRoot(replies);

  int threadRootOf(int messageId, List<ChatMessage> replies) =>
      _threads.rootOf(messageId, replies);

  /// The attachment as a local file path (downloads it if needed).
  Future<Result<String>> attachmentFile(
    String accountId,
    MessageContent content,
  ) => _open(accountId: accountId, content: content);

  /// Stops downloading an attachment the user opened.
  /// Saves a copy of an attachment at [targetPath] (a pass-through).
  Future<Result<void>> saveAttachmentCopy(
    String accountId,
    MessageContent content,
    String targetPath,
  ) => _repository.saveAttachmentCopy(accountId, content, targetPath);

  /// The user's last saved copy of an attachment, if still on disk.
  Future<String?> savedAttachmentCopy(
    String accountId,
    MessageContent content,
  ) => _repository.savedAttachmentCopy(accountId, content);

  /// Stops sending a file still uploading and removes its message (a CRUD
  /// pass-through).
  Future<Result<void>> cancelUpload(String accountId, String messageGid) =>
      _repository.cancelUpload(accountId, messageGid);

  void cancelDownload(String accountId, MessageContent content) =>
      _repository.cancelDownload(accountId, content);

  Future<Result<Uint8List>> videoThumbnail(
    String accountId,
    MessageContent video,
  ) => _thumbnail(accountId: accountId, video: video);
}
