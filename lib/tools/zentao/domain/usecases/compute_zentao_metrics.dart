import '../../../../core/domain/entities/account.dart';
import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/tools/tool_module.dart';
import '../../../../shared/board/domain/usecases/is_assigned_to_me.dart';

/// Computes the overview metrics for a ZenTao account from the local DB tickets:
/// the open tasks and the open bugs assigned to the account's user. The account
/// holds the whole team's tickets, which say nothing about your own work.
class ComputeZentaoMetrics {
  const ComputeZentaoMetrics();

  ToolMetrics call({required List<Ticket> tickets, required Account account}) {
    var openTasks = 0;
    var openBugs = 0;

    for (final ticket in tickets) {
      if (ticket.accountId != account.id ||
          ticket.providerType != ProviderType.zentao ||
          !const IsAssignedToMe()(ticket, account)) {
        continue;
      }

      final isTask =
          ticket.externalType?.toLowerCase() == 'task' ||
          ticket.providerEntity is ZenTaoTaskEntity;
      final isBug =
          ticket.externalType?.toLowerCase() == 'bug' ||
          ticket.providerEntity is ZenTaoBugEntity;

      final isOpen =
          ticket.status != UnifiedStatus.done &&
          ticket.providerStatus.toLowerCase() != 'closed' &&
          ticket.providerStatus.toLowerCase() != 'done' &&
          ticket.providerStatus.toLowerCase() != 'cancel';

      if (isTask && isOpen) {
        openTasks++;
      } else if (isBug && isOpen) {
        openBugs++;
      }
    }

    return ToolMetrics(
      primaryCount: openTasks,
      primaryLabel: (l) => l.zentaoMyOpenTasks,
      secondaryCount: openBugs,
      secondaryLabel: (l) => l.zentaoMyOpenBugs,
    );
  }
}
