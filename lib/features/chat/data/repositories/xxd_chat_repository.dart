import 'dart:async';

import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/parse_message_content.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../../domain/value_objects/message_content.dart';
import '../datasources/chat_file_cache.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/video_thumbnailer.dart';
import '../datasources/xxd/xxd_connection.dart';
import '../datasources/xxd/xxd_connection_state.dart';
import '../datasources/xxd/xxd_http_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../datasources/xxd/xxd_server_info.dart';
import '../mappers/chat_mappers.dart';
import 'chat_attachment_loader.dart';
import 'chat_credentials_resolver.dart';
import 'chat_history_sync.dart';
import 'chat_packet_ingestor.dart';
import 'chat_sender.dart';
import 'chat_session.dart';

/// Opens an [XxdConnection] for the given credentials (injected for tests).
typedef XxdConnectionFactory = XxdConnection Function(XxdCredentials);

/// Reports a background failure that has no caller to return it to (a packet
/// that could not be stored, a follow-up fetch that failed).
typedef ChatErrorSink = void Function(Object error, StackTrace stack);

/// [ChatRepository] over xxd. One connection per ZenTao account; every packet
/// is written to drift by [ChatPacketIngestor] and the UI watches drift.
class XxdChatRepository implements ChatRepository {
  XxdChatRepository({
    required ChatLocalDatasource local,
    required CredentialStore credentials,
    required XxdConnectionFactory openConnection,
    required ChatErrorSink onError,
    required XxdHttpDatasource http,
    ChatFileCache? files,
    VideoThumbnailer thumbnailer = const VideoThumbnailer(),
    ParseMessageContent parse = const ParseMessageContent(),
    DateTime Function() now = DateTime.now,
  }) : _local = local,
       _openConnection = openConnection,
       _onError = onError,
       _parse = parse,
       _now = now,
       _ingestor = ChatPacketIngestor(local),
       _resolver = ChatCredentialsResolver(local, credentials),
       _history = ChatHistorySync(local, ChatPacketIngestor(local)),
       _attachments = ChatAttachmentLoader(
         http,
         files ?? ChatFileCache.appDefault(),
       ),
       _thumbnailer = thumbnailer;

  /// Messages still pending after this long are treated as interrupted.
  static const pendingTimeout = Duration(minutes: 2);
  static const pageSize = ChatHistorySync.pageSize;

  final ChatLocalDatasource _local;
  final XxdConnectionFactory _openConnection;
  final ChatErrorSink _onError;
  final ParseMessageContent _parse;
  final DateTime Function() _now;
  final ChatPacketIngestor _ingestor;
  final ChatCredentialsResolver _resolver;
  final ChatHistorySync _history;
  final ChatAttachmentLoader _attachments;
  final VideoThumbnailer _thumbnailer;
  late final ChatSender _sender = ChatSender(
    local: _local,
    attachments: _attachments,
    session: (accountId) => _sessions[accountId],
    ingest: _ingest,
    now: _now,
  );
  final _sessions = <String, ChatSession>{};

  final _statuses = <String, StatusChannel>{};

  // ---- connection --------------------------------------------------------------

  @override
  Stream<ChatConnectionStatus> watchStatus(String accountId) =>
      _status(accountId).watch();

  @override
  Future<Result<void>> connect(String accountId) async {
    final existing = _sessions[accountId];
    if (existing != null && existing.isActive) return const Ok(null);
    await _closeSession(accountId);

    final credentials = await _resolver.resolve(accountId);
    final XxdCredentials creds;
    switch (credentials) {
      case Ok(:final value):
        creds = value;
      case Err(:final failure):
        _status(
          accountId,
        ).set(ChatConnectionStatus.signedOut(message: failure.message));
        return Err(failure);
    }
    await _local.failStalePending(accountId, _now().subtract(pendingTimeout));

    final connection = _openConnection(creds);
    final session = ChatSession(connection);
    _sessions[accountId] = session;
    session.listen(
      onPacket: (p) => session.enqueue(() => _ingest(accountId, session, p)),
      onState: (s) => _onState(accountId, session, s),
      onError: _onError,
    );
    final result = await connection.start();
    return switch (result) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<void> disconnect(String accountId) async {
    await _closeSession(accountId);
    _status(accountId).set(const ChatConnectionStatus.offline());
  }

  @override
  Future<Result<void>> trustCertificate(
    String accountId,
    String fingerprint,
  ) async {
    try {
      await _local.saveChatAccount(
        ChatAccountsCompanion(
          accountId: Value(accountId),
          pinnedFingerprint: Value(fingerprint),
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not save the certificate', cause: e));
    }
    await _closeSession(accountId);
    return connect(accountId);
  }

  void _onState(String accountId, ChatSession session, XxdConnectionState s) {
    if (_sessions[accountId] != session) return;
    final status = switch (s) {
      XxdDisconnected() => const ChatConnectionStatus.offline(),
      XxdConnecting() => const ChatConnectionStatus.connecting(),
      XxdOnline(:final session) => ChatConnectionStatus.online(
        selfUserId: session.userId,
      ),
      XxdReconnecting(:final delay, :final lastFailure) =>
        ChatConnectionStatus.reconnecting(
          retryIn: delay,
          reason: lastFailure.message,
        ),
      XxdStopped(failure: final UntrustedCertificateFailure f) =>
        ChatConnectionStatus.needsTrust(
          host: f.host,
          fingerprint: f.fingerprint,
          subject: f.subject,
          issuer: f.issuer,
        ),
      XxdStopped(:final failure, :final kicked) =>
        ChatConnectionStatus.signedOut(
          message: failure.message,
          kicked: kicked,
        ),
    };
    _status(accountId).set(status);
    if (s is XxdOnline) {
      session.selfUserId = s.session.userId;
      session.enqueue(
        () => _local.saveChatAccount(
          ChatAccountsCompanion(
            accountId: Value(accountId),
            userId: Value(s.session.userId),
          ),
        ),
      );
    }
  }

  Future<void> _closeSession(String accountId) async {
    final session = _sessions.remove(accountId);
    await session?.close();
  }

  StatusChannel _status(String accountId) =>
      _statuses.putIfAbsent(accountId, StatusChannel.new);

  // ---- ingest ------------------------------------------------------------------

  final _incoming = StreamController<ChatMessage>.broadcast();

  @override
  Stream<ChatMessage> watchIncoming() => _incoming.stream;

  Future<void> _ingest(
    String accountId,
    ChatSession session,
    XxdResponse packet,
  ) async {
    final self = session.selfUserId;
    // Only a live push of a message not stored before is "new": the reply to
    // our own send, re-deliveries and retract/edit pushes are not.
    final fresh = <String>[];
    if (packet.isSuccess && packet.apiName == 'messagesend') {
      final data = packet.data;
      for (final m in data is List ? data : [data]) {
        if (m is! Map || m['gid'] is! String || m['deleted'] == true) continue;
        final gid = m['gid']! as String;
        if (await _local.message(accountId, gid) == null) fresh.add(gid);
      }
    }
    final followUp = await _ingestor.ingest(
      accountId,
      packet,
      selfUserId: self,
    );
    session.fetchMissing(followUp);
    for (final gid in fresh) {
      final row = await _local.message(accountId, gid);
      if (row == null || row.senderId == self) continue;
      _incoming.add(messageFromRow(row, selfUserId: self, parse: _parse));
    }
  }

  // ---- reads -------------------------------------------------------------------

  @override
  Stream<List<ChatConversation>> watchConversations(String accountId) =>
      withSelfUserId(
        _local.watchSelfUserId(accountId),
        _local.watchConversations(accountId),
        (rows, self) => [
          for (final (conv, last) in rows)
            conversationFromRow(
              conv,
              lastMessage: last,
              selfUserId: self,
              parse: _parse,
            ),
        ],
      );

  @override
  Stream<List<ChatMessage>> watchMessages(
    String accountId,
    String chatGid, {
    int limit = pageSize,
  }) => withSelfUserId(
    _local.watchSelfUserId(accountId),
    _local.watchMessages(accountId, chatGid, limit: limit),
    (rows, self) => [
      for (final r in rows) messageFromRow(r, selfUserId: self, parse: _parse),
    ],
  );

  @override
  Stream<ChatMessage?> watchMessage(
    String accountId,
    String chatGid,
    int serverId,
  ) => withSelfUserId(
    _local.watchSelfUserId(accountId),
    _local.watchMessageByServerId(accountId, chatGid, serverId),
    (row, self) => row == null
        ? null
        : messageFromRow(row, selfUserId: self, parse: _parse),
  );

  @override
  Stream<List<ChatMessage>> watchReplies(String accountId, String chatGid) =>
      withSelfUserId(
        _local.watchSelfUserId(accountId),
        _local.watchReplies(accountId, chatGid),
        (rows, self) => [
          for (final r in rows)
            messageFromRow(r, selfUserId: self, parse: _parse),
        ],
      );

  @override
  Stream<List<ChatUser>> watchUsers(String accountId) => _local
      .watchUsers(accountId)
      .map((rows) => rows.map(userFromRow).toList());

  // ---- history & read state ----------------------------------------------------

  @override
  Future<Result<void>> refreshMessages(String accountId, String chatGid) =>
      _history.refresh(_sessions[accountId], accountId, chatGid);

  @override
  Future<Result<int>> loadOlderMessages(String accountId, String chatGid) =>
      _history.loadOlder(_sessions[accountId], accountId, chatGid);

  @override
  Future<Result<void>> fetchMessages(
    String accountId,
    String chatGid,
    List<int> serverIds,
  ) => _history.fetchByIds(_sessions[accountId], accountId, chatGid, serverIds);

  @override
  Future<Result<void>> markRead(String accountId, String chatGid) async {
    final ChatConversationRow? row;
    try {
      row = await _local.conversation(accountId, chatGid);
      if (row == null || row.lastReadIndex >= row.lastMessageIndex) {
        return const Ok(null);
      }
      await _local.setLastReadIndex(accountId, chatGid, row.lastMessageIndex);
    } on Exception catch (e) {
      return Err(StorageFailure('Could not mark the chat read', cause: e));
    }
    final session = _sessions[accountId];
    // Offline: read locally now; the server keeps its own value until the
    // chat is read again while connected.
    if (session == null || !session.isOnline) return const Ok(null);
    final reply = await session.connection.request(
      XxdRequest(
        'chatSetLastReadMessageByIndex',
        params: [chatGid, row.lastMessageIndex],
      ),
    );
    return switch (reply) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<Uint8List>> loadAttachment(
    String accountId,
    MessageContent content, {
    bool thumbnail = false,
  }) => _attachments.load(
    accountId,
    _sessions[accountId],
    content,
    thumbnail: thumbnail,
  );

  // ---- send --------------------------------------------------------------------

  @override
  Future<Result<void>> sendText(
    String accountId,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
  }) => _sender.sendText(
    accountId,
    chatGid,
    text,
    replyToId: replyToId,
    markdown: markdown,
  );

  @override
  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  }) => _sender.sendFile(
    accountId,
    chatGid,
    name: name,
    bytes: bytes,
    mimeType: mimeType,
    replyToId: replyToId,
  );

  @override
  Stream<double> watchUploadProgress(String messageGid) => _sender
      .uploadProgress
      .where((p) => p.gid == messageGid)
      .map((p) => p.sent);

  @override
  Future<Result<String>> attachmentFile(
    String accountId,
    MessageContent content,
  ) => _attachments.localFile(accountId, _sessions[accountId], content);

  /// Videos above this are not downloaded just to show a preview frame.
  /// Bigger ones show their size and download on tap instead.
  static const maxThumbnailSource = 20 * 1024 * 1024;

  @override
  Future<Result<Uint8List>> videoThumbnail(
    String accountId,
    MessageContent video,
  ) async {
    if (video case FileContent(:final size) when size > maxThumbnailSource) {
      // Downloaded on request since: a frame can be made from the file.
      if (!await _attachments.isCached(accountId, video)) {
        return const Err(NotFoundFailure('Video too large to preview'));
      }
    }
    // A frame made earlier outlives the video in the cache: no download.
    final cached = await _attachments.cachedPath(accountId, video);
    if (cached != null) {
      final frame = await _thumbnailer.cachedThumbnailOf(cached);
      if (frame != null) return Ok(frame);
    }
    final path = await attachmentFile(accountId, video);
    switch (path) {
      case Ok(:final value):
        final frame = await _thumbnailer.thumbnailOf(value);
        return frame == null
            ? const Err(NotFoundFailure('No preview frame'))
            : Ok(frame);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<int>> memberCount(String accountId, String chatGid) async =>
      switch (await members(accountId, chatGid)) {
        Ok(:final value) => Ok(value.length),
        Err(:final failure) => Err(failure),
      };

  @override
  Stream<double> watchDownloadProgress(
    String accountId,
    MessageContent content,
  ) => _attachments.watchProgress(accountId, content);

  @override
  Future<bool> isAttachmentCached(String accountId, MessageContent content) =>
      _attachments.isCached(accountId, content);

  @override
  Stream<int?> watchSelfUserId(String accountId) =>
      _local.watchSelfUserId(accountId);

  @override
  Future<Result<String>> openDirectChat(String accountId, int userId) async {
    final session = _sessions[accountId];
    final self = session?.selfUserId;
    if (session == null || self == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    // The official client sorts the ids as strings ("40" < "9").
    final gid = (['$self', '$userId']..sort()).join('&');
    if (await _local.conversation(accountId, gid) != null) return Ok(gid);
    final reply = await _requestAndStore(
      accountId,
      session,
      XxdRequest(
        'chatCreate',
        params: [
          gid,
          '',
          'one2one',
          [self, userId],
          0,
          false,
        ],
      ),
    );
    return switch (reply) {
      Ok() => Ok(gid),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<void>> setMessagePinned(
    String accountId,
    String chatGid,
    int serverId, {
    required bool pinned,
  }) async {
    final session = _sessions[accountId];
    final self = session?.selfUserId;
    if (session == null || self == null) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    return _requestAndStore(
      accountId,
      session,
      XxdRequest(
        pinned ? 'chatPinMessages' : 'chatUnpinMessages',
        params: [
          chatGid,
          [serverId],
          self,
        ],
      ),
    );
  }

  /// Sends [request] and writes its reply to the DB like a pushed packet.
  Future<Result<void>> _requestAndStore(
    String accountId,
    ChatSession session,
    XxdRequest request,
  ) async {
    final reply = await session.connection.request(request);
    switch (reply) {
      case Ok(:final value):
        if (!value.isSuccess) {
          return Err(UnexpectedFailure(value.message ?? 'The server refused'));
        }
        await session.enqueue(() => _ingest(accountId, session, value));
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  @override
  Future<Result<List<int>>> members(String accountId, String chatGid) async {
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final reply = await session.connection.request(
      XxdRequest('chatGetMembers', params: [chatGid]),
    );
    final Object? data;
    switch (reply) {
      case Ok(:final value):
        data = value.data;
      case Err(:final failure):
        return Err(failure);
    }
    final raw = data is Map ? data['members'] : data;
    if (raw is! List) {
      return const Err(ParseFailure('Unexpected chat members reply'));
    }
    // Members come as ids or as user objects depending on the server.
    final ids = <int>[
      for (final m in raw)
        if (m is num)
          m.toInt()
        else if (m is String && int.tryParse(m) != null)
          int.parse(m)
        else if (m is Map && m['id'] is num)
          (m['id']! as num).toInt(),
    ];
    final known = await _local.knownUserIds(accountId);
    session.fetchMissing(
      IngestFollowUp(userIds: ids.toSet().difference(known)),
    );
    return Ok(ids);
  }

  @override
  Future<Result<void>> retract(String accountId, String messageGid) =>
      _sender.retract(accountId, messageGid);

  @override
  Future<Result<void>> retrySend(String accountId, String messageGid) =>
      _sender.retrySend(accountId, messageGid);
}
