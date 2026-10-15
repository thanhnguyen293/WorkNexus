import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/tools/tool_module.dart';

/// Computes the overview metrics for a ZenTao account from the local DB tickets.
/// ZenTao primary metric: open tasks. Secondary metric: open bugs (specs S6.1).
class ComputeZentaoMetrics {
  const ComputeZentaoMetrics();

  ToolMetrics call({required List<Ticket> tickets, required String accountId}) {
    var openTasks = 0;
    var openBugs = 0;

    for (final ticket in tickets) {
      if (ticket.accountId != accountId ||
          ticket.providerType != ProviderType.zentao) {
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
      primaryLabel: (l) => l.dashboardStatTasks,
      secondaryCount: openBugs,
      secondaryLabel: (l) => l.dashboardStatBugs,
    );
  }
}
