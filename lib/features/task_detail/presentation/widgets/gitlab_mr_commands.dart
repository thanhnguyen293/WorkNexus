/// The state-changing actions on a GitLab merge request. The detail runs each
/// through its use case; the panels and the header menu only trigger them. Each
/// completes once the action and the refresh after it are done, so the button
/// that started it can show a spinner meanwhile.
class GitLabMrCommands {
  const GitLabMrCommands({
    required this.approve,
    required this.unapprove,
    required this.merge,
    required this.rebase,
    required this.close,
    required this.reopen,
    required this.setDraft,
  });

  final Future<void> Function() approve;
  final Future<void> Function() unapprove;
  final Future<void> Function({
    required bool squash,
    required bool removeSourceBranch,
  })
  merge;
  final Future<void> Function() rebase;
  final Future<void> Function() close;
  final Future<void> Function() reopen;

  /// Marks the MR as a draft (true) or ready for review (false).
  final Future<void> Function(bool draft) setDraft;
}
