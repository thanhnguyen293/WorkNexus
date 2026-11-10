import '../../../../core/usecase/usecase.dart';
import 'check_zentao_task_input.dart';

/// Checks the hours left an unfinished task is assigned with: ZenTao's assign
/// form requires them and refuses 0 (`taskModel::assign`). Null when fine.
class CheckZenTaoAssignLeft extends UseCase<ZenTaoTaskInputProblem?, double> {
  const CheckZenTaoAssignLeft();

  @override
  ZenTaoTaskInputProblem? call(double left) {
    if (left.isNaN || left < 0) return ZenTaoTaskInputProblem.invalidHours;
    if (left == 0) return ZenTaoTaskInputProblem.leftRequired;
    return null;
  }
}
