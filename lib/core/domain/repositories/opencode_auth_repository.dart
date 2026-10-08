import '../../error/result.dart';
import '../entities/opencode_credential.dart';

/// Read/write access to the credentials the `opencode` CLI authenticates with —
/// the same store `opencode auth login` maintains.
///
/// Lives in the shared kernel (CLAUDE.md rule 5.4) because more than one feature
/// depends on it: translation runs `opencode run`, dispatched coding agents
/// spawn the same binary, and the settings screen manages the key. Only API keys
/// are writable; an OAuth login has to be redone through the CLI itself.
abstract class OpenCodeAuthRepository {
  /// Every provider OpenCode currently has credentials for, sorted by id.
  Future<Result<List<OpenCodeCredential>>> listCredentials();

  /// Stores [key] as the API key for [providerId], replacing any existing entry
  /// for that provider and leaving the other providers untouched.
  Future<Result<void>> saveApiKey({
    required String providerId,
    required String key,
  });

  /// Drops [providerId]'s credentials — the equivalent of `opencode auth logout`.
  Future<Result<void>> removeCredential(String providerId);
}
