import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/build_reply_thread.dart';
import '../../domain/usecases/connect_chat.dart';
import '../../domain/usecases/fetch_chat_messages.dart';
import '../../domain/usecases/load_chat_attachment.dart';
import '../../domain/usecases/load_older_messages.dart';
import '../../domain/usecases/load_video_thumbnail.dart';
import '../../domain/usecases/mark_chat_read.dart';
import '../../domain/usecases/open_chat_attachment.dart';
import '../../domain/usecases/refresh_chat_messages.dart';
import '../../domain/usecases/retract_message.dart';
import '../../domain/usecases/retry_send_message.dart';
import '../../domain/usecases/send_chat_file.dart';
import '../../domain/usecases/send_text_message.dart';
import '../../domain/usecases/trust_chat_certificate.dart';
import '../../domain/value_objects/message_content.dart';

/// The chat view's commands. Each delegates to one use case; widgets show the
/// returned [Result] (CLAUDE.md 2.4, 11.3).
class ChatController {
  ChatController(ChatRepository repository)
    : _connect = ConnectChat(repository),
      _trust = TrustChatCertificate(repository),
      _send = SendTextMessage(repository),
      _retry = RetrySendMessage(repository),
      _refresh = RefreshChatMessages(repository),
      _older = LoadOlderMessages(repository),
      _markRead = MarkChatRead(repository),
      _attachment = LoadChatAttachment(repository),
      _fetch = FetchChatMessages(repository),
      _sendFile = SendChatFile(repository),
      _retract = RetractMessage(repository),
      _open = OpenChatAttachment(repository),
      _thumbnail = LoadVideoThumbnail(repository);

  static const pageSize = 50;

  final ConnectChat _connect;
  final TrustChatCertificate _trust;
  final SendTextMessage _send;
  final RetrySendMessage _retry;
  final RefreshChatMessages _refresh;
  final LoadOlderMessages _older;
  final MarkChatRead _markRead;
  final LoadChatAttachment _attachment;
  final FetchChatMessages _fetch;
  final SendChatFile _sendFile;
  final RetractMessage _retract;
  final OpenChatAttachment _open;
  final LoadVideoThumbnail _thumbnail;
  final _threads = const BuildReplyThread();

  Future<Result<void>> connect(String accountId) => _connect(accountId);

  Future<Result<void>> trust(String accountId, String fingerprint) =>
      _trust(accountId: accountId, fingerprint: fingerprint);

  Future<Result<void>> send(
    String accountId,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
  }) => _send(
    accountId: accountId,
    chatGid: chatGid,
    text: text,
    replyToId: replyToId,
    markdown: markdown,
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

  Future<Result<int>> loadOlder(String accountId, String chatGid) =>
      _older(accountId: accountId, chatGid: chatGid);

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

  Future<Result<Uint8List>> videoThumbnail(
    String accountId,
    MessageContent video,
  ) => _thumbnail(accountId: accountId, video: video);
}
