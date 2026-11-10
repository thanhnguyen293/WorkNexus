import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/database.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_doc.dart';
import '../../domain/entities/zentao_doc_action.dart';
import '../../domain/entities/zentao_doc_lib.dart';
import '../../domain/entities/zentao_doc_pins.dart';
import '../../domain/entities/zentao_doc_summary.dart';
import '../../domain/repositories/zentao_doc_repository.dart';
import '../datasources/zentao_docs_remote.dart';
import '../mappers/zentao_doc_history_mapper.dart';
import '../mappers/zentao_doc_mapper.dart';

/// The document endpoints for [account], or null when it has no stored
/// credentials. The composition root hands out the sync's pooled client: a
/// login of this repository's own would end the sync's ZenTao session.
typedef ZenTaoDocsRemoteFactory =
    Future<ZenTaoDocsRemote?> Function(Account account);

/// Where saved files go; null when the platform has no Downloads folder.
typedef DownloadsDirectoryFinder = Future<Directory?> Function();

class LocalZenTaoDocRepository implements ZenTaoDocRepository {
  LocalZenTaoDocRepository(
    this._db,
    this._remoteFor, {
    DownloadsDirectoryFinder? downloads,
  }) : _downloads = downloads ?? getDownloadsDirectory;

  final AppDatabase _db;
  final ZenTaoDocsRemoteFactory _remoteFor;
  final DownloadsDirectoryFinder _downloads;

  static const _libsKey = 'libs';
  static const _pinsKey = 'pins';
  static String _libKey(String libId) => 'lib:$libId';
  static String _docKey(String docId) => 'doc:$docId';
  static String _historyKey(String docId) => 'history:$docId';

  @override
  Stream<List<ZenTaoDocLib>> watchLibs(String accountId) => _watch(
    accountId,
    _libsKey,
  ).map((json) => json == null ? const [] : mapZenTaoDocLibs(json));

  @override
  Stream<List<ZenTaoDocSummary>> watchDocs(String accountId, String libId) =>
      _watch(accountId, _libKey(libId)).map(
        (json) => json == null ? const [] : mapZenTaoDocSummaries(json, libId),
      );

  @override
  Stream<ZenTaoDoc?> watchDoc(String accountId, String docId) =>
      _watch(accountId, _docKey(docId)).map((json) {
        final doc = json?['doc'];
        if (doc is! Map) return null;
        return mapZenTaoDoc(
          Map<String, dynamic>.from(doc),
          baseUrl: '${json?['base'] ?? ''}',
        );
      });

  @override
  Future<Result<void>> refreshLibs(Account account) =>
      _refresh(account, _libsKey, (remote) => remote.libs());

  @override
  Future<Result<void>> refreshDocs(Account account, String libId) =>
      _refresh(account, _libKey(libId), (remote) => remote.docs(libId));

  @override
  Future<Result<void>> refreshDoc(Account account, String docId) =>
      _refresh(account, _docKey(docId), (remote) async {
        final json = await remote.doc(docId);
        // A document the user may not read comes back without its fields;
        // storing it would replace a readable cached copy with nothing.
        if (mapZenTaoDoc(json, baseUrl: remote.baseUrl) == null) {
          throw const _Unreadable();
        }
        // The base URL is kept beside the document: its files' links are
        // built from it on read.
        return {'base': remote.baseUrl, 'doc': json};
      });

  @override
  Stream<List<ZenTaoDocAction>> watchHistory(String accountId, String docId) =>
      _watch(
        accountId,
        _historyKey(docId),
      ).map((json) => json == null ? const [] : mapZenTaoDocHistory(json));

  @override
  Future<Result<void>> refreshHistory(Account account, String docId) =>
      _refresh(account, _historyKey(docId), (remote) => remote.history(docId));

  @override
  Stream<ZenTaoDocPins> watchPins(String accountId) =>
      _watch(accountId, _pinsKey).map(
        (json) => json == null ? const ZenTaoDocPins() : mapZenTaoDocPins(json),
      );

  @override
  Future<Result<void>> savePins(String accountId, ZenTaoDocPins pins) async {
    try {
      await _db
          .into(_db.zenTaoDocSnapshots)
          .insertOnConflictUpdate(
            ZenTaoDocSnapshotsCompanion.insert(
              accountId: accountId,
              key: _pinsKey,
              json: jsonEncode(zenTaoDocPinsToJson(pins)),
              fetchedAt: DateTime.now(),
            ),
          );
      return const Ok(null);
    } on Exception catch (error) {
      return Err(StorageFailure('Could not save the pins', cause: error));
    }
  }

  @override
  Future<Uint8List?> fetchImage(Account account, String url) async {
    try {
      return await (await _remoteFor(account))?.image(url);
    } on Exception {
      return null;
    }
  }

  @override
  Future<Result<Uint8List>> readFile(
    Account account,
    TicketAttachment file,
  ) async {
    try {
      final remote = await _remoteFor(account);
      if (remote == null) {
        return const Err(AuthFailure('No ZenTao connection credentials'));
      }
      final bytes = await remote.download(file.url);
      return bytes == null
          ? const Err(NetworkFailure('Could not download the file'))
          : Ok(bytes);
    } on DioException catch (error) {
      return Err(_httpFailure(error, 'Could not download the file'));
    }
  }

  @override
  Future<Result<String>> saveFile(
    Account account,
    TicketAttachment file,
  ) async {
    try {
      final remote = await _remoteFor(account);
      if (remote == null) {
        return const Err(AuthFailure('No ZenTao connection credentials'));
      }
      final bytes = await remote.download(file.url);
      if (bytes == null) {
        return const Err(NetworkFailure('Could not download the file'));
      }
      final dir = await _downloads();
      if (dir == null) {
        return const Err(StorageFailure('No Downloads folder'));
      }
      final dest = await _freePath(dir, _safeName(file.title));
      await File(dest).writeAsBytes(bytes, flush: true);
      return Ok(dest);
    } on DioException catch (error) {
      return Err(_httpFailure(error, 'Could not download the file'));
    } on FileSystemException catch (error) {
      return Err(StorageFailure('Could not save the file', cause: error));
    }
  }

  Stream<Map<String, dynamic>?> _watch(String accountId, String key) =>
      (_db.select(_db.zenTaoDocSnapshots)..where(
            (row) => row.accountId.equals(accountId) & row.key.equals(key),
          ))
          .watchSingleOrNull()
          .map((row) {
            if (row == null) return null;
            final decoded = jsonDecode(row.json);
            return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
          })
          .distinct(_sameJson);

  Future<Result<void>> _refresh(
    Account account,
    String key,
    Future<Map<String, dynamic>> Function(ZenTaoDocsRemote remote) fetch,
  ) async {
    try {
      final remote = await _remoteFor(account);
      if (remote == null) {
        return const Err(AuthFailure('No ZenTao connection credentials'));
      }
      final encoded = jsonEncode(await fetch(remote));
      final stored =
          await (_db.select(_db.zenTaoDocSnapshots)..where(
                (row) => row.accountId.equals(account.id) & row.key.equals(key),
              ))
              .getSingleOrNull();
      // An unchanged reply leaves the row (and its watchers) alone.
      if (stored?.json == encoded) return const Ok(null);
      await _db
          .into(_db.zenTaoDocSnapshots)
          .insertOnConflictUpdate(
            ZenTaoDocSnapshotsCompanion.insert(
              accountId: account.id,
              key: key,
              json: encoded,
              fetchedAt: DateTime.now(),
            ),
          );
      return const Ok(null);
    } on _Unreadable {
      return const Err(NotFoundFailure('ZenTao document is not readable'));
    } on DioException catch (error) {
      return Err(_httpFailure(error, 'Could not load ZenTao documents'));
    } on FormatException catch (error) {
      return Err(ParseFailure('Invalid ZenTao document reply', cause: error));
    }
  }

  Failure _httpFailure(DioException error, String message) {
    final code = error.response?.statusCode;
    return switch (code) {
      401 => AuthFailure('ZenTao authentication failed', cause: error),
      403 || 404 => NotFoundFailure(message, cause: error),
      _ => NetworkFailure(message, cause: error),
    };
  }

  static bool _sameJson(Map<String, dynamic>? a, Map<String, dynamic>? b) =>
      jsonEncode(a) == jsonEncode(b);

  static String _safeName(String name) {
    final safe = name.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
    return safe.isEmpty ? 'file' : safe;
  }

  /// [name] in [dir], numbered (`name (2).ext`) when a file already has it.
  static Future<String> _freePath(Directory dir, String name) async {
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var candidate = '${dir.path}${Platform.pathSeparator}$name';
    for (var n = 2; await File(candidate).exists(); n++) {
      candidate = '${dir.path}${Platform.pathSeparator}$stem ($n)$ext';
    }
    return candidate;
  }
}

class _Unreadable implements Exception {
  const _Unreadable();
}
