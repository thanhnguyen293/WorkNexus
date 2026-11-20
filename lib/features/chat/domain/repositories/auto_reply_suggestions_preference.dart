import '../../../../core/error/result.dart';

/// Whether reply ideas are asked for on their own while a chat is open, on
/// this device. Off until the user turns it on: each run costs a model call.
abstract class AutoReplySuggestionsPreference {
  Future<Result<bool>> isEnabled();

  Future<Result<void>> setEnabled(bool enabled);
}
