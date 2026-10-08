import '../../../../core/domain/repositories/opencode_auth_repository.dart';
import '../../../../core/error/result.dart';

/// Unlinks a provider from OpenCode — the equivalent of `opencode auth logout`.
class RemoveOpenCodeCredential {
  const RemoveOpenCodeCredential(this._repository);

  final OpenCodeAuthRepository _repository;

  Future<Result<void>> call(String providerId) =>
      _repository.removeCredential(providerId);
}
