import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/domain/value_objects/zentao_task_action_input.dart';
import '../../../../core/usecase/usecase.dart';

/// Why a task action's input would be refused by ZenTao.
enum ZenTaoTaskInputProblem {
  /// Hours must be a number, 0 or more.
  invalidHours,

  /// Starting, continuing or reopening needs the hours left (above 0 — at 0,
  /// ZenTao finishes the task instead).
  leftRequired,

  /// Finishing a task with nothing logged needs the hours worked.
  spentRequired,
}

/// What [action] is to send, and the hours already [logged] on the task.
typedef ZenTaoTaskInputQuery = ({
  ZenTaoTaskAction action,
  ZenTaoTaskActionInput input,
  double logged,
});

/// Checks a task action's input before it is sent; null when it is fine.
class CheckZenTaoTaskInput
    extends UseCase<ZenTaoTaskInputProblem?, ZenTaoTaskInputQuery> {
  const CheckZenTaoTaskInput();

  @override
  ZenTaoTaskInputProblem? call(ZenTaoTaskInputQuery q) {
    final ZenTaoTaskInputQuery(:action, :input, :logged) = q;
    final hours = [
      if (action.asksSpent) input.spent,
      if (action.asksLeft) input.left,
    ];
    if (hours.any((h) => h.isNaN || h < 0)) {
      return ZenTaoTaskInputProblem.invalidHours;
    }
    if (action.asksLeft && input.left <= 0) {
      return ZenTaoTaskInputProblem.leftRequired;
    }
    if (action == ZenTaoTaskAction.finish && input.spent <= 0 && logged <= 0) {
      return ZenTaoTaskInputProblem.spentRequired;
    }
    return null;
  }
}
