import '../../../../core/error/result.dart';

/// Brings a ZenTao task's related bugs into the local database: ZenTao keeps
/// the link on the bug (its `task`), and lists bugs by execution, so they are
/// read from the task's execution's bug list and the detail panel picks the
/// task's out of the stored bugs.
abstract interface class ZenTaoTaskBugs {
  /// Stores the bugs of task [taskId] (its ZenTao id) in execution
  /// [executionId] for account [accountId] — unless a recent read already
  /// covered them.
  Future<Result<void>> syncTaskBugs({
    required String accountId,
    required String executionId,
    required String taskId,
  });
}
