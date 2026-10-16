import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/provider_type.dart';

/// The GitHub tickets a board of [accountId] shows before the user's filters:
/// that account's items, in repository [scopeId] when one is open — the same
/// scope the section's list view applies.
List<Ticket> scopeGitHubTickets(
  List<Ticket> tickets, {
  required String? accountId,
  required String? scopeId,
}) => [
  for (final t in tickets)
    if (t.providerType == ProviderType.github &&
        (accountId == null || t.accountId == accountId) &&
        (scopeId == null ||
            switch (t.providerEntity) {
                  GitHubItemEntity(:final repo) => repo,
                  _ => t.projectId,
                } ==
                scopeId))
      t,
];
