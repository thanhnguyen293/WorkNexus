import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/usecase/usecase.dart';
import '../value_objects/gitlab_mr_column.dart';
import 'filter_tickets.dart';

class GitLabMrBoardColumn {
  const GitLabMrBoardColumn({required this.column, required this.tickets});

  final GitLabMrColumn column;
  final List<Ticket> tickets;

  int get count => tickets.length;
}

class GitLabMrBoardModel {
  const GitLabMrBoardModel({required this.columns});

  final List<GitLabMrBoardColumn> columns;

  int get total => columns.fold(0, (sum, col) => sum + col.count);

  GitLabMrBoardColumn column(GitLabMrColumn column) =>
      columns.firstWhere((c) => c.column == column);
}

/// Groups the filtered GitLab merge requests into the native MR lifecycle
/// columns, keyed off the raw `providerStatus` (`draft`/`opened`/`merged`/`closed`).
class BuildGitLabMrBoard extends UseCase<GitLabMrBoardModel, BoardQuery> {
  const BuildGitLabMrBoard({this.filter = const FilterTickets()});

  final FilterTickets filter;

  @override
  GitLabMrBoardModel call(BoardQuery q) {
    final byColumn = <GitLabMrColumn, List<Ticket>>{
      for (final column in GitLabMrColumn.columns) column: <Ticket>[],
    };
    for (final ticket in filter(q)) {
      if (!_isGitLabMr(ticket)) continue;
      byColumn[gitlabMrColumnFor(ticket)]!.add(ticket);
    }
    return GitLabMrBoardModel(
      columns: [
        for (final column in GitLabMrColumn.columns)
          GitLabMrBoardColumn(
            column: column,
            tickets: byColumn[column]!..sort(byPriorityThenUpdated),
          ),
      ],
    );
  }
}

bool _isGitLabMr(Ticket ticket) =>
    ticket.providerType == ProviderType.gitlab &&
    (ticket.externalType ?? '').toLowerCase() == 'mergerequest';

GitLabMrColumn gitlabMrColumnFor(Ticket ticket) =>
    switch (ticket.providerStatus.toLowerCase()) {
      'draft' => GitLabMrColumn.draft,
      'merged' => GitLabMrColumn.merged,
      'closed' => GitLabMrColumn.closed,
      _ => GitLabMrColumn.review,
    };

int byPriorityThenUpdated(Ticket a, Ticket b) {
  final p = a.priority.level.compareTo(b.priority.level);
  if (p != 0) return p;
  final au = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final bu = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return bu.compareTo(au);
}
