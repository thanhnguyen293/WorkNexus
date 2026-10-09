import '../../error/result.dart';
import '../entities/ticket.dart';
import '../value_objects/zentao_action.dart';
import '../value_objects/zentao_task_action_input.dart';

/// ZenTao's status actions on bugs and tasks. Each shows its outcome on the
/// ticket at once, then refreshes it from ZenTao (or puts it back on failure).
abstract interface class ZenTaoWorkflowService {
  /// Confirms a new bug; it goes to [assignee] (default: me).
  Future<Result<void>> confirmBug(
    Ticket ticket, {
    String? assignee,
    String? comment,
  });

  /// Reopens a resolved or closed bug, found again in [build] (default:
  /// trunk); it goes to [assignee] (default: me).
  Future<Result<void>> activateBug(
    Ticket ticket, {
    String? build,
    String? assignee,
    String? comment,
  });

  /// Closes a resolved bug.
  Future<Result<void>> closeBug(Ticket ticket, {String? comment});

  /// Runs [action] on a task with what its form asks for ([input]).
  Future<Result<void>> runTaskAction(
    Ticket ticket,
    ZenTaoTaskAction action,
    ZenTaoTaskActionInput input,
  );
}
