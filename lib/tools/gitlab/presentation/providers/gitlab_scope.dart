import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// The GitLab tickets a board of [accountId] shows before the user's filters:
/// that account's items, in project [scopeId] when one is open — the same
/// scope the section's list view applies.
List<Ticket> scopeGitLabTickets(
  List<Ticket> tickets, {
  required String? accountId,
  required String? scopeId,
}) => [
  for (final t in tickets)
    if (t.providerType == ProviderType.gitlab &&
        (accountId == null || t.accountId == accountId) &&
        (scopeId == null || gitlabTicketInProject(t, scopeId)))
      t,
];

/// Whether [t] is in the GitLab project [scopeId]. The sidebar scopes by the
/// project's numeric id (`ProviderProject.id`); a ticket keeps it on its
/// entity, beside the `group/name` path its `projectId` is built from.
bool gitlabTicketInProject(Ticket t, String scopeId) {
  if (t.providerEntity case GitLabItemEntity(
    :final projectId,
    :final projectPath,
  )) {
    if (projectId?.toString() == scopeId || projectPath == scopeId) return true;
  }
  return t.projectId == scopeId;
}
