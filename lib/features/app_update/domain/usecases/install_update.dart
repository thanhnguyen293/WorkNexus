import '../../../../core/error/result.dart';
import '../repositories/update_repository.dart';

/// Replaces the running app with the build staged at a path and restarts it.
class InstallUpdate {
  const InstallUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<void>> call(String stagedPath) =>
      _repository.install(stagedPath);
}
