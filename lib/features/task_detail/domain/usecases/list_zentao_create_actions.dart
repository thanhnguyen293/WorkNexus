import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/zentao_create_action.dart';

/// What can be started from a ZenTao bug or task: a bug is copied; a task
/// gets bugs, and subtasks while it is open — but a subtask gets none of its
/// own (ZenTao 18.x nests one level only), and its execution must be known
/// (a subtask is filed there).
class ListZenTaoCreateActions
    extends UseCase<List<ZenTaoCreateAction>, Ticket> {
  const ListZenTaoCreateActions();

  @override
  List<ZenTaoCreateAction> call(Ticket ticket) {
    final raw = ticket.providerStatus.trim().toLowerCase();
    return switch ((ticket.externalType ?? '').toLowerCase()) {
      'bug' => const [ZenTaoCreateAction.copyBug],
      'task' => [
        if (ticket.providerEntity case ZenTaoTaskEntity(
          parentId: null,
          execution: _?,
        ) when raw != 'closed' && raw != 'cancel')
          ZenTaoCreateAction.subtask,
        ZenTaoCreateAction.bugFromTask,
      ],
      _ => const [],
    };
  }
}
