import '../../../../core/error/result.dart';

/// Brings a ZenTao task's related bugs into the local database: ZenTao keeps
/// the link on the bug (its `task`), and lists bugs by execution, so the
/// task's execution's bugs are stored and the detail panel picks the task's
/// out of them.
abstract interface class ZenTaoTaskBugs {
  /// Stores execution [executionId]'s bugs for account [accountId].
  Future<Result<void>> syncExecutionBugs({
    required String accountId,
    required String executionId,
  });
}
