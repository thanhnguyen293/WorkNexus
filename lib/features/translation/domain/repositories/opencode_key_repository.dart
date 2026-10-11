import '../../../../core/error/result.dart';
import '../entities/opencode_provider_auth.dart';

/// The API keys the `opencode` CLI translates with — the same store
/// `opencode auth login` maintains, so a key saved here is what the CLI uses.
abstract class OpenCodeKeyRepository {
  Future<Result<OpenCodeProviderAuth>> authFor(String providerId);

  /// Stores [key] as [providerId]'s API key, replacing that provider's entry
  /// and leaving every other provider's login untouched.
  Future<Result<void>> saveApiKey({
    required String providerId,
    required String key,
  });
}
