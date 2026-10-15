import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';
import '../entities/zentao_profile.dart';
import '../repositories/zentao_profile_repository.dart';

class RefreshZenTaoProfile {
  const RefreshZenTaoProfile(this._repository);

  final ZenTaoProfileRepository _repository;

  Future<Result<ZenTaoProfile>> call(Account account) =>
      _repository.refresh(account);
}
