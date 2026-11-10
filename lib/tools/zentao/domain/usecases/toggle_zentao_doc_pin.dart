import '../../../../core/error/result.dart';
import '../entities/zentao_doc_lib.dart';
import '../entities/zentao_doc_summary.dart';
import '../repositories/zentao_doc_repository.dart';

/// Pins a library or a document to the top of an account's Docs pane, or
/// unpins it when it is already there. Give exactly one of [lib] and [doc].
class ToggleZenTaoDocPin {
  const ToggleZenTaoDocPin(this._repository);

  final ZenTaoDocRepository _repository;

  Future<Result<void>> call(
    String accountId, {
    ZenTaoDocLib? lib,
    ZenTaoDocSummary? doc,
  }) async {
    assert((lib == null) != (doc == null), 'give a library or a document');
    final pins = await _repository.watchPins(accountId).first;
    final next = lib != null ? pins.togglingLib(lib) : pins.togglingDoc(doc!);
    return _repository.savePins(accountId, next);
  }
}
