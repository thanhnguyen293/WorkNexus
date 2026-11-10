import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../repositories/zentao_doc_repository.dart';

/// Fetches an account's document libraries into the local cache.
class RefreshZenTaoDocLibs {
  const RefreshZenTaoDocLibs(this._repository);

  final ZenTaoDocRepository _repository;

  Future<Result<void>> call(Account account) =>
      _repository.refreshLibs(account);
}
