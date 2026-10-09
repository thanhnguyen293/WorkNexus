import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/zentao_action_menu.dart';
import '../value_objects/zentao_bug_action.dart';

/// The actions ZenTao offers on a bug in its current state — the same rules as
/// its own toolbar (`bugModel::isClickable`).
class ListZenTaoBugActions
    extends UseCase<ZenTaoActionMenu<ZenTaoBugAction>, Ticket> {
  const ListZenTaoBugActions();

  @override
  ZenTaoActionMenu<ZenTaoBugAction> call(Ticket ticket) {
    final raw = ticket.providerStatus.trim().toLowerCase();
    final active = raw == 'active';
    // An active bug sits in the inbox until it is confirmed (see the ZenTao
    // status mapping), which also tracks an optimistic confirm.
    final unconfirmed = active && ticket.status == UnifiedStatus.inbox;
    bool offers(ZenTaoBugAction action) => switch (action) {
      ZenTaoBugAction.confirm => unconfirmed,
      ZenTaoBugAction.resolve => active,
      ZenTaoBugAction.close => raw == 'resolved',
      ZenTaoBugAction.activate => raw == 'resolved' || raw == 'closed',
    };
    return (
      canAssign: raw.isNotEmpty && raw != 'closed',
      actions: ZenTaoBugAction.values.where(offers).toList(),
    );
  }
}
