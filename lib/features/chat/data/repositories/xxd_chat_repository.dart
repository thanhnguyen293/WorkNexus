import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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
import '../datasources/chat_local_datasource.dart';
import '../datasources/xxd/xxd_connection.dart';
import '../datasources/xxd/xxd_connection_state.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../datasources/xxd/xxd_server_info.dart';
import '../mappers/chat_mappers.dart';
import 'chat_credentials_resolver.dart';
import 'chat_packet_ingestor.dart';
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
    ParseMessageContent parse = const ParseMessageContent(),
    DateTime Function() now = DateTime.now,
  }) : _local = local,
       _openConnection = openConnection,
       _onError = onError,
       _parse = parse,
       _now = now,
       _ingestor = ChatPacketIngestor(local),
       _resolver = ChatCredentialsResolver(local, credentials);

  /// Messages still pending after this long are treated as interrupted.
  static const pendingTimeout = Duration(minutes: 2);
  static const pageSize = 50;

  final ChatLocalDatasource _local;
  final XxdConnectionFactory _openConnection;
  final ChatErrorSink _onError;
  final ParseMessageContent _parse;
  final DateTime Function() _now;
  final ChatPacketIngestor _ingestor;
  final ChatCredentialsResolver _resolver;
  final _uuid = const Uuid();
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

  Future<void> _ingest(
    String accountId,
    ChatSession session,
    XxdResponse packet,
  ) async {
    final followUp = await _ingestor.ingest(
      accountId,
      packet,
      selfUserId: session.selfUserId,
    );
    _fetchMissing(session, followUp);
  }

  /// Fire-and-forget: the replies come back as packets and are ingested.
  void _fetchMissing(ChatSession session, IngestFollowUp followUp) {
    if (followUp.userIds.isNotEmpty) {
      unawaited(
        session.connection.request(
          XxdRequest('usergetlist', params: [followUp.userIds.toList()]),
        ),
      );
    }
    for (final gid in followUp.chatGids) {
      unawaited(
        session.connection.request(XxdRequest('chatgetbygid', params: [gid])),
      );
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
  Stream<List<ChatUser>> watchUsers(String accountId) => _local
      .watchUsers(accountId)
      .map((rows) => rows.map(userFromRow).toList());

  // ---- history -----------------------------------------------------------------

  @override
  Future<Result<void>> refreshMessages(String accountId, String chatGid) async {
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final info = await session.connection.request(
      XxdRequest('chatGetMessageInfo', params: [chatGid]),
    );
    final int last;
    switch (info) {
      case Ok(:final value):
        final data = value.data;
        final lastMessage = data is Map ? data['lastMessage'] : null;
        last = lastMessage is num ? lastMessage.toInt() : 0;
      case Err(:final failure):
        return Err(failure);
    }
    if (last <= 0) return const Ok(null);
    final page = await _syncPage(session, accountId, chatGid, from: last);
    return switch (page) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }

  @override
  Future<Result<int>> loadOlderMessages(
    String accountId,
    String chatGid,
  ) async {
    final session = _sessions[accountId];
    if (session == null) return const Err(NetworkFailure('Chat is offline'));
    final oldest = await _local.oldestServerId(accountId, chatGid);
    if (oldest == null) {
      final refreshed = await refreshMessages(accountId, chatGid);
      return switch (refreshed) {
        Ok() => const Ok(0),
        Err(:final failure) => Err(failure),
      };
    }
    if (oldest <= 1) return const Ok(0);
    final page = await _syncPage(session, accountId, chatGid, from: oldest - 1);
    return switch (page) {
      Ok(:final value) => Ok(
        value
            .where((m) => ((m['id'] as num?)?.toInt() ?? oldest) < oldest)
            .length,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  /// `messageSync` backwards from server message id [from] (inclusive).
  Future<Result<List<Map<String, Object?>>>> _syncPage(
    ChatSession session,
    String accountId,
    String chatGid, {
    required int from,
  }) async {
    final reply = await session.connection.request(
      XxdRequest('messageSync', params: [chatGid, from, true, pageSize, false]),
    );
    switch (reply) {
      case Ok(:final value):
        final data = value.data;
        final messages = [
          if (data is List)
            for (final m in data)
              if (m is Map) Map<String, Object?>.from(m),
        ];
        await session.enqueue(() async {
          final followUp = await _ingestor.storeMessages(
            accountId,
            messages,
            selfUserId: session.selfUserId,
          );
          _fetchMissing(session, followUp);
        });
        return Ok(messages);
      case Err(:final failure):
        return Err(failure);
    }
  }

  // ---- send --------------------------------------------------------------------

  @override
  Future<Result<void>> sendText(
    String accountId,
    String chatGid,
    String text,
  ) async {
    final gid = _uuid.v4();
    final self =
        _sessions[accountId]?.selfUserId ??
        (await _local.chatAccount(accountId))?.userId ??
        0;
    try {
      await _local.insertMessage(
        ChatMessagesCompanion.insert(
          accountId: accountId,
          gid: gid,
          cgid: chatGid,
          senderId: self,
          sentAt: _now(),
          contentType: 'plain',
          content: text,
          sendState: Value(SendState.pending.name),
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not queue the message', cause: e));
    }
    return _deliver(accountId, gid);
  }

  @override
  Future<Result<void>> retrySend(String accountId, String messageGid) async {
    final row = await _local.message(accountId, messageGid);
    if (row == null || row.sendState != SendState.failed.name) {
      return const Err(NotFoundFailure('No failed message to retry'));
    }
    await _local.setSendState(accountId, messageGid, SendState.pending);
    return _deliver(accountId, messageGid);
  }

  Future<Result<void>> _deliver(String accountId, String gid) async {
    final session = _sessions[accountId];
    final row = await _local.message(accountId, gid);
    final self = session?.selfUserId;
    if (session == null || row == null || self == null) {
      await _local.setSendState(accountId, gid, SendState.failed);
      return const Err(NetworkFailure('Chat is offline'));
    }
    final reply = await session.connection.request(
      XxdRequest(
        'messagesend',
        params: [
          [
            {
              'gid': row.gid,
              'cgid': row.cgid,
              'type': 'normal',
              'contentType': row.contentType,
              'content': row.content,
              'user': self,
              'data': '',
              'deleted': false,
            },
          ],
        ],
      ),
    );
    switch (reply) {
      case Ok(:final value):
        // The echo is also ingested as a packet; storing it here as well makes
        // the message "sent" even if that packet is handled later.
        await session.enqueue(() => _ingest(accountId, session, value));
        await _local.setSendState(accountId, gid, SendState.sent);
        return const Ok(null);
      case Err(:final failure):
        await _local.setSendState(accountId, gid, SendState.failed);
        return Err(failure);
    }
  }
}
