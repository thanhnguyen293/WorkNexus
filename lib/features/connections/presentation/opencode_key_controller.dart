import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/domain/entities/opencode_credential.dart';
import '../../../core/domain/repositories/opencode_auth_repository.dart';
import '../../../core/error/result.dart';
import '../domain/usecases/load_opencode_credentials.dart';
import '../domain/usecases/remove_opencode_credential.dart';
import '../domain/usecases/save_opencode_key.dart';

/// The providers OpenCode is authenticated with. Kept as a [Result] rather than
/// a thrown error so the card renders a [Failure] message instead of a raw
/// exception (CLAUDE.md rule 11.3). Invalidated after every successful write.
final openCodeCredentialsProvider =
    FutureProvider.autoDispose<Result<List<OpenCodeCredential>>>(
      (ref) => LoadOpenCodeCredentials(getIt<OpenCodeAuthRepository>())(),
    );

/// In-flight / last-error state of the add-or-change-key form.
class OpenCodeKeyState {
  const OpenCodeKeyState({this.busy = false, this.error, this.done = false});

  final bool busy;
  final String? error;

  /// Set once the write succeeded, so the dialog can close itself.
  final bool done;
}

/// Writes OpenCode API keys through the use cases and reports the outcome.
class OpenCodeKeyController extends Notifier<OpenCodeKeyState> {
  @override
  OpenCodeKeyState build() => const OpenCodeKeyState();

  void reset() => state = const OpenCodeKeyState();

  Future<void> saveKey({required String providerId, required String key}) =>
      _run(
        () => SaveOpenCodeKey(getIt<OpenCodeAuthRepository>())(
          providerId: providerId,
          key: key,
        ),
      );

  Future<void> remove(String providerId) => _run(
    () => RemoveOpenCodeCredential(getIt<OpenCodeAuthRepository>())(providerId),
  );

  Future<void> _run(Future<Result<void>> Function() action) async {
    state = const OpenCodeKeyState(busy: true);
    final result = await action();
    state = result.fold(
      (_) => const OpenCodeKeyState(done: true),
      (failure) => OpenCodeKeyState(error: failure.message),
    );
    if (result.isOk) ref.invalidate(openCodeCredentialsProvider);
  }
}

final openCodeKeyControllerProvider =
    NotifierProvider<OpenCodeKeyController, OpenCodeKeyState>(
      OpenCodeKeyController.new,
    );
