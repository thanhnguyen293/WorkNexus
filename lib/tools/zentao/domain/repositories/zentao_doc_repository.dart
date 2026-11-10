import 'dart:typed_data';

import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/error/result.dart';
import '../entities/zentao_doc.dart';
import '../entities/zentao_doc_action.dart';
import '../entities/zentao_doc_lib.dart';
import '../entities/zentao_doc_pins.dart';
import '../entities/zentao_doc_summary.dart';

/// ZenTao documents, read-only. The `watch*` streams read the local cache
/// (the source of truth); the `refresh*` calls fetch from the server and
/// write the cache, which the streams then emit.
abstract class ZenTaoDocRepository {
  Stream<List<ZenTaoDocLib>> watchLibs(String accountId);
  Stream<List<ZenTaoDocSummary>> watchDocs(String accountId, String libId);
  Stream<ZenTaoDoc?> watchDoc(String accountId, String docId);

  Future<Result<void>> refreshLibs(Account account);
  Future<Result<void>> refreshDocs(Account account, String libId);
  Future<Result<void>> refreshDoc(Account account, String docId);

  /// A document's history, oldest first.
  Stream<List<ZenTaoDocAction>> watchHistory(String accountId, String docId);
  Future<Result<void>> refreshHistory(Account account, String docId);

  /// The account's pinned libraries and documents (stored locally only).
  Stream<ZenTaoDocPins> watchPins(String accountId);
  Future<Result<void>> savePins(String accountId, ZenTaoDocPins pins);

  /// An image embedded in a document body, through the authenticated session.
  Future<Uint8List?> fetchImage(Account account, String url);

  /// A document's attached [file], downloaded for showing in place.
  Future<Result<Uint8List>> readFile(Account account, TicketAttachment file);

  /// Saves a document's attached [file] to the user's Downloads folder and
  /// returns the saved path.
  Future<Result<String>> saveFile(Account account, TicketAttachment file);
}
