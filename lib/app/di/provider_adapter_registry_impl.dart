import '../../core/domain/adapters/provider_adapter.dart';
import '../../core/domain/adapters/provider_adapter_registry.dart';
import '../../core/domain/entities/account.dart';
import '../../core/domain/value_objects/provider_type.dart';
import '../../tools/github/data/datasources/github_client.dart';
import '../../tools/github/data/repositories/github_adapter.dart';
import '../../tools/gitlab/data/datasources/gitlab_client.dart';
import '../../tools/gitlab/data/repositories/gitlab_adapter.dart';
import '../../tools/zentao/data/datasources/zentao_client.dart';
import '../../tools/zentao/data/repositories/zentao_adapter.dart';

/// Implementation of [ProviderAdapterRegistry] in the composition root.
class ProviderAdapterRegistryImpl implements ProviderAdapterRegistry {
  const ProviderAdapterRegistryImpl();

  @override
  ProviderAdapter? createAdapter(
    Account account,
    String secret, {
    dynamic zenClient,
  }) => buildProviderAdapter(
    account,
    secret,
    zenClient: zenClient is ZenTaoClient ? zenClient : null,
  );
}

/// Builds a live [ProviderAdapter] for a configured account + its secret.
/// Returns null for providers not yet implemented (Jira).
///
/// [zenClient], [gitlabClient] and [githubClient] let the caller inject a
/// shared client instead of minting a throwaway one. ZenTao rotates (and
/// invalidates) its session id on every login, so two clients for the same
/// account fighting over the session would churn the token — callers that
/// also load session-protected assets (inline images, attachments) MUST pass
/// the same pooled client the asset loader uses. GitLab and GitHub need no
/// session, but a fresh client per call is a fresh TCP + TLS handshake per
/// sync, detail open and action; a pooled one keeps the connection.
ProviderAdapter? buildProviderAdapter(
  Account account,
  String secret, {
  ZenTaoClient? zenClient,
  GitLabClient? gitlabClient,
  GitHubClient? githubClient,
}) {
  switch (account.providerType) {
    case ProviderType.zentao:
      return ZenTaoAdapter(
        accountId: account.id,
        client:
            zenClient ??
            ZenTaoClient(
              baseUrl: account.baseUrl ?? '',
              account: account.handle,
              password: secret,
            ),
      );
    case ProviderType.gitlab:
      return GitLabAdapter(
        accountId: account.id,
        client:
            gitlabClient ??
            GitLabClient(baseUrl: account.baseUrl ?? '', token: secret),
      );
    case ProviderType.github:
      return GitHubAdapter(
        accountId: account.id,
        client:
            githubClient ??
            GitHubClient(baseUrl: account.baseUrl ?? '', token: secret),
      );
    case ProviderType.jira:
      return null;
  }
}
