import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../repositories/zentao_doc_repository.dart';

/// Fetches one document (body and files) into the local cache.
class RefreshZenTaoDoc {
  const RefreshZenTaoDoc(this._repository);

  final ZenTaoDocRepository _repository;

  Future<Result<void>> call(Account account, String docId) =>
      _repository.refreshDoc(account, docId);
}
