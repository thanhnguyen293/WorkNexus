import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../repositories/zentao_doc_repository.dart';

/// Fetches one library's document list into the local cache.
class RefreshZenTaoDocs {
  const RefreshZenTaoDocs(this._repository);

  final ZenTaoDocRepository _repository;

  Future<Result<void>> call(Account account, String libId) =>
      _repository.refreshDocs(account, libId);
}
