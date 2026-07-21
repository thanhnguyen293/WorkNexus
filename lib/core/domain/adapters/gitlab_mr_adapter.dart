import '../../error/result.dart';
import '../entities/ticket.dart';
import 'provider_adapter.dart';

abstract interface class GitLabMrAdapter implements ProviderAdapter {
  Future<Result<List<ProviderUser>>> listProjectMembers(Ticket ticket);

  Future<Result<bool>> closeIssue(Ticket ticket);

  Future<Result<bool>> reopenIssue(Ticket ticket);

  Future<Result<bool>> closeMergeRequest(Ticket ticket);

  Future<Result<bool>> reopenMergeRequest(Ticket ticket);

  Future<Result<bool>> mergeMergeRequest(Ticket ticket);

  Future<Result<bool>> approveMergeRequest(Ticket ticket);

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
