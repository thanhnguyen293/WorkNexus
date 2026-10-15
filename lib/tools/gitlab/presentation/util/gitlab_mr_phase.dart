import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';

/// Where a GitLab merge request stands — read once from its raw status, so the
/// header menu, the widgets and the overview all agree.
enum GitLabMrPhase {
  draft,
  open,
  merged,
  closed;

  /// Still accepting changes (draft or ready for review).
  bool get isActive => this == draft || this == open;
}

GitLabMrPhase gitLabMrPhase(Ticket ticket, GitLabItemEntity entity) =>
    switch (ticket.providerStatus.toLowerCase()) {
      'merged' => GitLabMrPhase.merged,
      'closed' => GitLabMrPhase.closed,
      'draft' => GitLabMrPhase.draft,
      _ => (entity.draft ?? false) ? GitLabMrPhase.draft : GitLabMrPhase.open,
    };

/// Whether GitLab will refuse the merge until the source branch is rebased:
/// its own `need_rebase` status, or — on fast-forward / semi-linear projects,
/// where that status can still read `mergeable` — any commits behind target.
bool gitLabMrNeedsRebase(GitLabItemEntity entity) =>
    entity.mergeStatus == 'need_rebase' || (entity.commitsBehind ?? 0) > 0;
