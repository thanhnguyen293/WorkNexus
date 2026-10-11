import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/error/result.dart';
import '../domain/entities/opencode_provider_auth.dart';
import '../domain/repositories/opencode_key_repository.dart';
import 'translation_providers.dart';

/// How OpenCode is signed in for one provider id.
final openCodeProviderAuthProvider = FutureProvider.autoDispose
    .family<Result<OpenCodeProviderAuth>, String>(
      (ref, providerId) => getIt<OpenCodeKeyRepository>().authFor(providerId),
    );

/// Saves an OpenCode API key, then refreshes everything that depends on the
/// CLI being signed in: the provider's status, the "is OpenCode linked" gate
/// and the model list (a new key can unlock more models).
class OpenCodeKeyController extends Notifier<void> {
  @override
  void build() {}

  Future<Result<void>> save({
    required String providerId,
    required String key,
  }) async {
    final result = await getIt<OpenCodeKeyRepository>().saveApiKey(
      providerId: providerId,
      key: key,
    );
    if (result.isOk) {
      ref
        ..invalidate(openCodeProviderAuthProvider(providerId))
        ..invalidate(openCodeAuthedProvider)
        ..invalidate(openCodeModelsProvider);
    }
    return result;
  }
}

final openCodeKeyControllerProvider =
    NotifierProvider<OpenCodeKeyController, void>(OpenCodeKeyController.new);
