import 'dart:typed_data';

import '../../error/result.dart';
import '../entities/ticket.dart';
import 'provider_adapter.dart';

/// Presentation-facing contract for the GitHub issue/PR detail actions, mirroring
/// [GitLabMrService]. Implemented by the sync layer; the detail UI depends only
/// on this interface (never the concrete data-layer service). GitHub has no
/// account-wide assignable list, no label/milestone/reaction/approve API through
/// a PAT, so only the supported actions are exposed here.
abstract interface class GitHubPrService {
  Future<Result<void>> postComment(Ticket ticket, String body);

  Future<Result<void>> closeGitHubItem(Ticket ticket);

  Future<Result<void>> reopenGitHubItem(Ticket ticket);

  Future<Result<void>> mergeGitHubPr(Ticket ticket);

  Future<Result<void>> updateGitHubPrBranch(Ticket ticket);

  Future<Result<void>> setReviewers(Ticket ticket, List<String> logins);

  Future<Result<void>> assignTicket(
    Ticket ticket, {
    required String assignee,
    String? comment,
  });

  Future<Result<List<ProviderUser>>> listUsers(Ticket ticket);

  Future<Uint8List?> fetchTicketImage(Ticket ticket, String url);
}
