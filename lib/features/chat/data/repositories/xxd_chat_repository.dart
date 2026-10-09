import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/debug/app_talker.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/credential_store.dart';
import '../../domain/entities/chat_cache_usage.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/parse_message_content.dart';
import '../../domain/value_objects/chat_connection_status.dart';
import '../../domain/value_objects/message_content.dart';
import '../datasources/chat_file_cache.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/video_duration_reader.dart';
import '../datasources/video_thumbnailer.dart';
import '../datasources/xxd/xxd_connection.dart';
import '../datasources/xxd/xxd_connection_state.dart';
import '../datasources/xxd/xxd_http_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../datasources/xxd/xxd_server_info.dart';
import '../mappers/chat_mappers.dart';
import 'chat_attachment_loader.dart';
import 'chat_avatar_service.dart';
import 'chat_cache_manager.dart';
import 'chat_credentials_resolver.dart';
import 'chat_history_sync.dart';
import 'chat_packet_ingestor.dart';
import 'chat_sender.dart';
import 'chat_session.dart';

part 'xxd_chat_repository_connection.dart';
part 'xxd_chat_repository_reads.dart';
part 'xxd_chat_repository_send.dart';
part 'xxd_chat_repository_attachments.dart';
part 'xxd_chat_repository_members.dart';
part 'xxd_chat_repository_chats.dart';

/// Opens an [XxdConnection] for the given credentials (injected for tests).
typedef XxdConnectionFactory = XxdConnection Function(XxdCredentials);

/// Reports a background failure that has no caller to return it to (a packet
/// that could not be stored, a follow-up fetch that failed).
typedef ChatErrorSink = void Function(Object error, StackTrace stack);

/// [ChatRepository] over xxd. One connection per ZenTao account; every packet
/// is written to drift by [ChatPacketIngestor] and the UI watches drift.
class XxdChatRepository extends _XxdChatCore
    with
        _ChatConnection,
        _ChatReads,
        _ChatSending,
        _ChatAttachments,
        _ChatMembers,
        _ChatActions {
  XxdChatRepository({
    required super.local,
    required super.credentials,
    required super.openConnection,
    required super.onError,
    required super.http,
    super.files,
    super.thumbnailer,
    super.durations,
    super.parse,
    super.now,
  });

  /// Messages still pending after this long are treated as interrupted.
  static const pendingTimeout = Duration(minutes: 2);
  static const pageSize = ChatHistorySync.pageSize;
}

/// State and helpers every part of [XxdChatRepository] shares: the injected
/// collaborators, the live sessions, packet ingest and request-and-store.
abstract class _XxdChatCore implements ChatRepository {
  _XxdChatCore({
    required ChatLocalDatasource local,
    required CredentialStore credentials,
    required this._openConnection,
    required this._onError,
    required XxdHttpDatasource http,
    ChatFileCache? files,
    this._thumbnailer = const VideoThumbnailer(),
    this._durations = const VideoDurationReader(),
    ParseMessageContent parse = const ParseMessageContent(),
    this._now = DateTime.now,
  }) : _local = local,
       _parse = parse,
       _ingestor = ChatPacketIngestor(local),
       _resolver = ChatCredentialsResolver(local, credentials),
       _history = ChatHistorySync(local, ChatPacketIngestor(local)),
       _files = files ?? ChatFileCache.appDefault() {
    _attachments = ChatAttachmentLoader(http, _files);
    _cache = ChatCacheManager(local, _files, _attachments, parse);
    _avatars = ChatAvatarService(http);
  }

  final ChatLocalDatasource _local;
  final XxdConnectionFactory _openConnection;
  final ChatErrorSink _onError;
  final ParseMessageContent _parse;
  final DateTime Function() _now;
  final ChatPacketIngestor _ingestor;
  final ChatCredentialsResolver _resolver;
  final ChatHistorySync _history;
  final ChatFileCache _files;
  late final ChatAttachmentLoader _attachments;
  late final ChatCacheManager _cache;
  late final ChatAvatarService _avatars;
  final VideoDurationReader _durations;
  final VideoThumbnailer _thumbnailer;
  late final ChatSender _sender = ChatSender(
    local: _local,
    attachments: _attachments,
    session: (accountId) => _sessions[accountId],
    ingest: _ingest,
    now: _now,
  );
  final _sessions = <String, ChatSession>{};

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
}
