import '../../../../core/domain/repositories/opencode_auth_repository.dart';
import '../../../../core/error/result.dart';

/// Sets (or replaces) the API key OpenCode uses for one provider.
class SaveOpenCodeKey {
  const SaveOpenCodeKey(this._repository);

  final OpenCodeAuthRepository _repository;

  Future<Result<void>> call({
    required String providerId,
    required String key,
  }) => _repository.saveApiKey(providerId: providerId, key: key);
}
