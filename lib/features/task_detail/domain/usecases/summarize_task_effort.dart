import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/task_effort.dart';

/// A task's hours for the detail header, or null when it has none on record.
///
/// Progress is logged over logged-plus-left, as ZenTao reckons it: the hours
/// left are the assignee's latest guess, so the estimate only sets the bar
/// before any work is logged.
class SummarizeTaskEffort extends UseCase<TaskEffort?, ZenTaoTaskEntity> {
  const SummarizeTaskEffort();

  @override
  TaskEffort? call(ZenTaoTaskEntity task) {
    final estimate = _hours(task.estimate);
    final consumed = _hours(task.consumed);
    final left = _hours(task.left);
    if (estimate == 0 && consumed == 0 && left == 0) return null;
    final total = consumed + left;
    return (
      estimate: estimate,
      consumed: consumed,
      left: left,
      progress: total == 0 ? 0 : (consumed / total).clamp(0, 1).toDouble(),
    );
  }

  /// Unset or nonsense hours count as none.
  double _hours(double? value) =>
      value == null || value.isNaN || value < 0 ? 0 : value;
}
