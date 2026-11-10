import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../repositories/zentao_doc_repository.dart';

/// Fetches a document's history into the local cache.
class RefreshZenTaoDocHistory {
  const RefreshZenTaoDocHistory(this._repository);

  final ZenTaoDocRepository _repository;

  Future<Result<void>> call(Account account, String docId) =>
      _repository.refreshHistory(account, docId);
}
