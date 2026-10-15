import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/zentao_action_menu.dart';

/// The actions ZenTao offers on a task in its current state — the same rules as
/// its own toolbar (`taskModel::isClickable`).
class ListZenTaoTaskActions
    extends UseCase<ZenTaoActionMenu<ZenTaoTaskAction>, Ticket> {
  const ListZenTaoTaskActions();

  /// What a parent task allows in both ZenTao 18.x and 20+: its status follows
  /// its subtasks, so it is never started, finished, reopened or reassigned
  /// by hand (and 18.x also refuses to pause or close it).
  static const _parentActions = {
    ZenTaoTaskAction.restart,
    ZenTaoTaskAction.cancel,
  };

  /// The actions that move a task forward, most pressing first: a task
  /// waiting is started, one in progress finished, a done one closed. Pause
  /// and cancel step aside, so they are never the main button.
  static const _forward = [
    ZenTaoTaskAction.start,
    ZenTaoTaskAction.restart,
    ZenTaoTaskAction.finish,
    ZenTaoTaskAction.close,
    ZenTaoTaskAction.activate,
  ];

  @override
  ZenTaoActionMenu<ZenTaoTaskAction> call(Ticket ticket) {
    final raw = ticket.providerStatus.trim().toLowerCase();
    final isParent = switch (ticket.providerEntity) {
      ZenTaoTaskEntity(:final isParent) => isParent,
      _ => false,
    };
    final ended = raw == 'done' || raw == 'closed' || raw == 'cancel';
    bool offers(ZenTaoTaskAction action) {
      if (isParent && !_parentActions.contains(action)) return false;
      return switch (action) {
        ZenTaoTaskAction.start => raw == 'wait',
        ZenTaoTaskAction.restart => raw == 'pause',
        ZenTaoTaskAction.pause => raw == 'doing',
        ZenTaoTaskAction.finish => raw.isNotEmpty && !ended,
        ZenTaoTaskAction.activate => ended,
        ZenTaoTaskAction.close => raw == 'done' || raw == 'cancel',
        ZenTaoTaskAction.cancel => raw.isNotEmpty && !ended,
      };
    }

    final actions = ZenTaoTaskAction.values.where(offers).toList();
    return (
      canAssign:
          !isParent && raw.isNotEmpty && raw != 'closed' && raw != 'cancel',
      actions: actions,
      primary: _forward.where(actions.contains).firstOrNull,
    );
  }
}
