/// The two GitHub object kinds the dedicated board can show. [externalType]
/// matches the `Ticket.externalType` stamped by `github_normalize` so the board
/// can filter tickets to one kind.
enum GitHubItemKind {
  issue(externalType: 'Issue'),
  pullRequest(externalType: 'PullRequest');

  const GitHubItemKind({required this.externalType});

  final String externalType;
}
