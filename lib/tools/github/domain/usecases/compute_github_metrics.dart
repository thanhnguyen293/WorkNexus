import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/tools/tool_module.dart';

/// Pure domain use case computing the primary and secondary metrics for a GitHub account.
/// Primary: Open Pull Requests.
/// Secondary: Open Issues.
class ComputeGithubMetrics {
  const ComputeGithubMetrics();

  ToolMetrics call({required List<Ticket> tickets, required String accountId}) {
    var openPulls = 0;
    var openIssues = 0;

    for (final ticket in tickets) {
      if (ticket.accountId != accountId) continue;
      if (ticket.providerType != ProviderType.github) continue;
      if (ticket.status == UnifiedStatus.done) continue;

      final isPr = (ticket.externalType ?? '').toLowerCase() == 'pullrequest';
      if (isPr) {
        openPulls++;
      } else {
        openIssues++;
      }
    }

    return ToolMetrics(
      primaryCount: openPulls,
      primaryLabel: (l) => l.githubPullRequests,
      secondaryCount: openIssues,
      secondaryLabel: (l) => l.githubIssues,
    );
  }
}
