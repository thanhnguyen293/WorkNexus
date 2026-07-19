import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/github_issue_column.dart';
import 'build_github_pr_board.dart' show githubByPriorityThenUpdated;
import 'filter_tickets.dart';

class GitHubIssueBoardColumn {
  const GitHubIssueBoardColumn({required this.column, required this.tickets});

  final GitHubIssueColumn column;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

class GitHubIssueBoardModel {
  const GitHubIssueBoardModel({required this.columns});

  final List<GitHubIssueBoardColumn> columns;

  int get total => columns.fold(0, (sum, col) => sum + col.count);

  GitHubIssueBoardColumn column(GitHubIssueColumn column) =>
      columns.firstWhere((c) => c.column == column);
}

/// Groups the filtered GitHub issues into open / in-progress / closed columns.
/// `closed` is keyed off the raw `providerStatus`; an open issue lands in
/// in-progress when its normalized status is `inprogress` (a "doing/wip" label).
class BuildGitHubIssueBoard extends UseCase<GitHubIssueBoardModel, BoardQuery> {
  const BuildGitHubIssueBoard({this.filter = const FilterTickets()});

  final FilterTickets filter;

  @override
  GitHubIssueBoardModel call(BoardQuery q) {
    final byColumn = <GitHubIssueColumn, List<Ticket>>{
      for (final column in GitHubIssueColumn.columns) column: <Ticket>[],
    };
    for (final ticket in filter(q)) {
      if (!_isGitHubIssue(ticket)) continue;
      byColumn[githubIssueColumnFor(ticket)]!.add(ticket);
    }
    return GitHubIssueBoardModel(
      columns: [
        for (final column in GitHubIssueColumn.columns)
          GitHubIssueBoardColumn(
            column: column,
            tickets: byColumn[column]!..sort(githubByPriorityThenUpdated),
          ),
      ],
    );
  }
}

bool _isGitHubIssue(Ticket ticket) =>
    ticket.providerType == ProviderType.github &&
    (ticket.externalType ?? '').toLowerCase() == 'issue';

GitHubIssueColumn githubIssueColumnFor(Ticket ticket) {
  if (ticket.providerStatus.toLowerCase() == 'closed') {
    return GitHubIssueColumn.closed;
  }
  return ticket.status == UnifiedStatus.inprogress
      ? GitHubIssueColumn.inProgress
      : GitHubIssueColumn.open;
}
