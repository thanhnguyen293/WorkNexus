import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/gitlab_issue_column.dart';
import 'build_gitlab_mr_board.dart' show byPriorityThenUpdated;
import 'filter_tickets.dart';

class GitLabIssueBoardColumn {
  const GitLabIssueBoardColumn({required this.column, required this.tickets});

  final GitLabIssueColumn column;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

class GitLabIssueBoardModel {
  const GitLabIssueBoardModel({required this.columns});

  final List<GitLabIssueBoardColumn> columns;

  int get total => columns.fold(0, (sum, col) => sum + col.count);

  GitLabIssueBoardColumn column(GitLabIssueColumn column) =>
      columns.firstWhere((c) => c.column == column);
}

/// Groups the filtered GitLab issues into open / in-progress / closed columns.
/// `closed` is keyed off the raw `providerStatus`; an open issue lands in
/// in-progress when its normalized status is `inprogress` (a "doing/wip" label).
class BuildGitLabIssueBoard extends UseCase<GitLabIssueBoardModel, BoardQuery> {
  const BuildGitLabIssueBoard({this.filter = const FilterTickets()});

  final FilterTickets filter;

  @override
  GitLabIssueBoardModel call(BoardQuery q) {
    final byColumn = <GitLabIssueColumn, List<Ticket>>{
      for (final column in GitLabIssueColumn.columns) column: <Ticket>[],
    };
    for (final ticket in filter(q)) {
      if (!_isGitLabIssue(ticket)) continue;
      byColumn[gitlabIssueColumnFor(ticket)]!.add(ticket);
    }
    return GitLabIssueBoardModel(
      columns: [
        for (final column in GitLabIssueColumn.columns)
          GitLabIssueBoardColumn(
            column: column,
            tickets: byColumn[column]!..sort(byPriorityThenUpdated),
          ),
      ],
    );
  }
}

bool _isGitLabIssue(Ticket ticket) =>
    ticket.providerType == ProviderType.gitlab &&
    (ticket.externalType ?? '').toLowerCase() == 'issue';

GitLabIssueColumn gitlabIssueColumnFor(Ticket ticket) {
  if (ticket.providerStatus.toLowerCase() == 'closed') {
    return GitLabIssueColumn.closed;
  }
  return ticket.status == UnifiedStatus.inprogress
      ? GitLabIssueColumn.inProgress
      : GitLabIssueColumn.open;
}
