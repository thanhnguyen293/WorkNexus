import '../../../../core/error/result.dart';
import '../entities/available_update.dart';
import '../repositories/update_repository.dart';

class DownloadUpdate {
  const DownloadUpdate(this._repository);

  final UpdateRepository _repository;

  Future<Result<String>> call(
    AvailableUpdate update, {
    void Function(double progress)? onProgress,
  }) => _repository.download(update, onProgress: onProgress);
}
