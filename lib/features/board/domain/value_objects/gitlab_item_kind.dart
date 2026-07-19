/// The two GitLab object kinds the dedicated board can show. [externalType]
/// matches the `Ticket.externalType` stamped by `gitlab_normalize` so the board
/// can filter tickets to one kind.
enum GitLabItemKind {
  issue(externalType: 'Issue'),
  mergeRequest(externalType: 'MergeRequest');

  const GitLabItemKind({required this.externalType});

  final String externalType;
}
