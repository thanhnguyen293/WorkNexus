import '../../../../core/error/result.dart';
import '../repositories/update_repository.dart';

class InstallUpdate {
  const InstallUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<void>> call(String stagedPath) =>
      _repository.install(stagedPath);
}
