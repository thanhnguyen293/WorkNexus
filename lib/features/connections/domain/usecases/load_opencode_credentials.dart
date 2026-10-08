import '../../../../core/domain/entities/opencode_credential.dart';
import '../../../../core/domain/repositories/opencode_auth_repository.dart';
import '../../../../core/error/result.dart';

/// Lists the providers OpenCode is authenticated with, for the settings screen.
class LoadOpenCodeCredentials {
  const LoadOpenCodeCredentials(this._repository);

  final OpenCodeAuthRepository _repository;

  Future<Result<List<OpenCodeCredential>>> call() =>
      _repository.listCredentials();
}
