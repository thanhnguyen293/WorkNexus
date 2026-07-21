import 'dart:typed_data';

import '../../error/result.dart';
import '../entities/ticket.dart';
import '../value_objects/repo_change.dart';
import 'provider_adapter.dart';

abstract interface class GitLabMrService {
  Future<Result<void>> postComment(Ticket ticket, String body);

  Future<Result<void>> closeGitLabItem(Ticket ticket);

  Future<Result<void>> approveGitLabMr(Ticket ticket);

  Future<Result<void>> mergeGitLabMr(Ticket ticket);

  Future<Result<void>> rebaseGitLabMr(Ticket ticket);

  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket);

  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  });

  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins);

  Future<Result<List<ProviderLabelOption>>> listGitLabLabels(Ticket ticket);

  Future<Result<void>> setGitLabLabels(Ticket ticket, List<String> labels);

  Future<Result<List<ProviderMilestoneOption>>> listGitLabMilestones(
    Ticket ticket,
  );

  Future<Result<void>> setGitLabMilestone(Ticket ticket, int? milestoneId);

  Future<Result<void>> updateGitLabTimeTracking(
    Ticket ticket, {
    String? estimate,
    String? spent,
    bool resetEstimate = false,
    bool resetSpent = false,
  });

  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url);

  Future<Result<List<RepoCommit>>> listMergeRequestCommits(Ticket ticket);

  Future<Result<List<RepoFileChange>>> listMergeRequestChanges(Ticket ticket);
}
