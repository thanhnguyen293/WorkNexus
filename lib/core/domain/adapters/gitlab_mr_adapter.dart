import '../../error/result.dart';
import '../entities/ticket.dart';
import '../value_objects/repo_change.dart';
import 'provider_adapter.dart';

abstract interface class GitLabMrAdapter implements ProviderAdapter {
  Future<Result<List<Ticket>>> listProjectItems(
    String projectId, {
    required bool mergeRequests,
  });

  Future<Result<List<Ticket>>> listMyMergeRequests();

  Future<String?> serverVersion();

  Future<Result<List<RepoCommit>>> listMergeRequestCommits(Ticket ticket);

  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(Ticket ticket);
  Future<Result<List<ProviderUser>>> listProjectMembers(Ticket ticket);

  Future<Result<bool>> closeIssue(Ticket ticket);

  Future<Result<bool>> reopenIssue(Ticket ticket);

  Future<Result<bool>> closeMergeRequest(Ticket ticket);

  Future<Result<bool>> reopenMergeRequest(Ticket ticket);

  /// Merges [ticket]; a null option keeps the MR's own setting.
  Future<Result<bool>> mergeMergeRequest(
    Ticket ticket, {
    bool? squash,
    bool? removeSourceBranch,
  });

  Future<Result<bool>> approveMergeRequest(Ticket ticket);

  Future<Result<bool>> unapproveMergeRequest(Ticket ticket);

  /// Marks [ticket] as a draft, or as ready when [draft] is false.
  Future<Result<bool>> setMergeRequestDraft(
    Ticket ticket, {
    required bool draft,
  });

  Future<Result<bool>> rebaseMergeRequest(Ticket ticket);

  Future<Result<bool>> setReviewers(Ticket ticket, List<String> logins);

  Future<Result<List<ProviderLabelOption>>> listProjectLabels(Ticket ticket);

  Future<Result<bool>> setLabels(Ticket ticket, List<String> labels);

  Future<Result<List<ProviderMilestoneOption>>> listProjectMilestones(
    Ticket ticket,
  );

  Future<Result<bool>> setMilestone(Ticket ticket, int? milestoneId);

  Future<Result<bool>> updateTimeTracking(
    Ticket ticket, {
    String? estimate,
    String? spent,
    bool resetEstimate = false,
    bool resetSpent = false,
  });
}
