import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/github_pr_column.dart';
import 'filter_tickets.dart';

class GitHubPrBoardColumn {
  const GitHubPrBoardColumn({required this.column, required this.tickets});

  final GitHubPrColumn column;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

class GitHubPrBoardModel {
  const GitHubPrBoardModel({required this.columns});

  final List<GitHubPrBoardColumn> columns;

  int get total => columns.fold(0, (sum, col) => sum + col.count);

  GitHubPrBoardColumn column(GitHubPrColumn column) =>
      columns.firstWhere((c) => c.column == column);
}

/// Groups the filtered GitHub pull requests into the native PR lifecycle
/// columns, keyed off the raw `providerStatus` (`draft`/`open`/`merged`/`closed`).
class BuildGitHubPrBoard extends UseCase<GitHubPrBoardModel, BoardQuery> {
  const BuildGitHubPrBoard({this.filter = const FilterTickets()});

  final FilterTickets filter;

  @override
  GitHubPrBoardModel call(BoardQuery q) {
    final byColumn = <GitHubPrColumn, List<Ticket>>{
      for (final column in GitHubPrColumn.columns) column: <Ticket>[],
    };
    for (final ticket in filter(q)) {
      if (!_isGitHubPr(ticket)) continue;
      byColumn[githubPrColumnFor(ticket)]!.add(ticket);
    }
    return GitHubPrBoardModel(
      columns: [
        for (final column in GitHubPrColumn.columns)
          GitHubPrBoardColumn(
            column: column,
            tickets: byColumn[column]!..sort(githubByPriorityThenUpdated),
          ),
      ],
    );
  }
}

bool _isGitHubPr(Ticket ticket) =>
    ticket.providerType == ProviderType.github &&
    (ticket.externalType ?? '').toLowerCase() == 'pullrequest';

GitHubPrColumn githubPrColumnFor(Ticket ticket) =>
    switch (ticket.providerStatus.toLowerCase()) {
      'draft' => GitHubPrColumn.draft,
      'merged' => GitHubPrColumn.merged,
      'closed' => GitHubPrColumn.closed,
      _ => GitHubPrColumn.review,
    };

/// Sort: higher priority first, then most-recently-updated. Shared by both
/// GitHub boards (kept local to the GitHub use cases to avoid a name clash with
/// the GitLab board's equivalent comparator).
int githubByPriorityThenUpdated(Ticket a, Ticket b) {
  final p = a.priority.level.compareTo(b.priority.level);
  if (p != 0) return p;
  final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bu.compareTo(au);
}
