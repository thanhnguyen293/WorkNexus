import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/tools/tool_module.dart';

/// Pure domain use case computing the primary and secondary metrics for a GitLab account.
/// Primary: cached projects count.
/// Secondary: open Merge Requests.
class ComputeGitlabMetrics {
  const ComputeGitlabMetrics();

  ToolMetrics call({
    required List<Ticket> tickets,
    required int projectCount,
    required String accountId,
  }) {
    var openMrs = 0;

    for (final ticket in tickets) {
      if (ticket.accountId != accountId) continue;
      if (ticket.providerType != ProviderType.gitlab) continue;
      if (ticket.status == UnifiedStatus.done) continue;

      final isMr = (ticket.externalType ?? '').toLowerCase() == 'mergerequest';
      if (isMr) {
        openMrs++;
      }
    }

    return ToolMetrics(
      primaryCount: projectCount,
      primaryLabel: (l) => l.allProjects,
      secondaryCount: openMrs,
      secondaryLabel: (l) => l.gitlabMergeRequests,
    );
  }
}
