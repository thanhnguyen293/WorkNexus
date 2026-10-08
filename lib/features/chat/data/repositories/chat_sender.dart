import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/chat_message.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/xxd/xxd_packet.dart';
import '../mappers/chat_mappers.dart';
import 'chat_attachment_loader.dart';
import 'chat_session.dart';

/// Outgoing messages: optimistic insert (pending), upload for files, the
/// `messagesend` round trip, retry and retract. The server's echo is applied
/// through [ingest] like any other packet.
class ChatSender {
  ChatSender({
    required ChatLocalDatasource local,
    required ChatAttachmentLoader attachments,
    required ChatSession? Function(String accountId) session,
    required Future<void> Function(String, ChatSession, XxdResponse) ingest,
    required DateTime Function() now,
  }) : _local = local,
       _attachments = attachments,
       _session = session,
       _ingest = ingest,
       _now = now;

  final ChatLocalDatasource _local;
  final ChatAttachmentLoader _attachments;
  final ChatSession? Function(String accountId) _session;
  final Future<void> Function(String, ChatSession, XxdResponse) _ingest;
  final DateTime Function() _now;
  final _uuid = const Uuid();

  final _progress = StreamController<({String gid, double sent})>.broadcast();

  /// Upload progress of pending file messages (0–1), by message gid.
  Stream<({String gid, double sent})> get uploadProgress => _progress.stream;

  /// Files whose upload has not succeeded yet, kept for retry.
  final _pendingUploads =
      <String, ({String name, Uint8List bytes, String? mimeType})>{};

  Future<Result<void>> sendText(
    String accountId,
    String chatGid,
    String text, {
    int? replyToId,
    bool markdown = false,
  }) async {
    final gid = _uuid.v4();
    final self =
        _session(accountId)?.selfUserId ??
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
          contentType: markdown ? 'text' : 'plain',
          content: text,
          sendState: Value(SendState.pending.name),
          replyToId: Value(replyToId),
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not queue the message', cause: e));
    }
    return _deliver(accountId, gid);
  }

  Future<Result<void>> sendFile(
    String accountId,
    String chatGid, {
    required String name,
    required Uint8List bytes,
    String? mimeType,
    int? replyToId,
  }) async {
    final gid = _uuid.v4();
    mimeType ??= mimeTypeForFileName(name);
    try {
      await _local.insertMessage(
        ChatMessagesCompanion.insert(
          accountId: accountId,
          gid: gid,
          cgid: chatGid,
          senderId: await _selfId(accountId),
          sentAt: _now(),
          contentType: isImageMime(mimeType) ? 'image' : 'file',
          // Placeholder until the upload returns the stored file's id.
          content: jsonEncode({'name': name, 'size': bytes.length}),
          sendState: Value(SendState.pending.name),
          replyToId: Value(replyToId),
        ),
      );
    } on Exception catch (e) {
      return Err(StorageFailure('Could not queue the file', cause: e));
    }
    _pendingUploads[gid] = (name: name, bytes: bytes, mimeType: mimeType);
    return _uploadAndDeliver(accountId, chatGid, gid);
  }

  Future<Result<void>> _uploadAndDeliver(
    String accountId,
    String chatGid,
    String gid,
  ) async {
    final file = _pendingUploads[gid];
    if (file == null) return _deliver(accountId, gid);
    final uploaded = await _attachments.upload(
      _session(accountId),
      chatGid: chatGid,
      name: file.name,
      bytes: file.bytes,
      mimeType: file.mimeType,
      onProgress: (sent) => _progress.add((gid: gid, sent: sent)),
    );
    switch (uploaded) {
      case Ok(:final value):
        _pendingUploads.remove(gid);
        await _local.setContent(
          accountId,
          gid,
          contentType: value.contentType,
          content: value.content,
        );
        return _deliver(accountId, gid);
      case Err(:final failure):
        await _local.setSendState(accountId, gid, SendState.failed);
        return Err(failure);
    }
  }

  Future<Result<void>> retract(String accountId, String messageGid) async {
    final session = _session(accountId);
    final row = await _local.message(accountId, messageGid);
    if (row == null) return const Err(NotFoundFailure('No such message'));
    if (session == null || !session.isOnline) {
      return const Err(NetworkFailure('Chat is offline'));
    }
    final reply = await session.connection.request(
      XxdRequest(
        'messageretract',
        params: [
          [
            {
              'gid': row.gid,
              'cgid': row.cgid,
              'type': 'normal',
              'contentType': row.contentType,
              'content': row.content,
              'user': row.senderId,
              'data': messageDataFor(replyToId: row.replyToId),
              'deleted': true,
            },
          ],
        ],
      ),
    );
    switch (reply) {
      case Ok(:final value):
        await session.enqueue(() => _ingest(accountId, session, value));
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  Future<int> _selfId(String accountId) async =>
      _session(accountId)?.selfUserId ??
      (await _local.chatAccount(accountId))?.userId ??
      0;

  Future<Result<void>> retrySend(String accountId, String messageGid) async {
    final row = await _local.message(accountId, messageGid);
    if (row == null || row.sendState != SendState.failed.name) {
      return const Err(NotFoundFailure('No failed message to retry'));
    }
    await _local.setSendState(accountId, messageGid, SendState.pending);
    return _uploadAndDeliver(accountId, row.cgid, messageGid);
  }

  Future<Result<void>> _deliver(String accountId, String gid) async {
    final session = _session(accountId);
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
              'data': messageDataFor(replyToId: row.replyToId),
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
