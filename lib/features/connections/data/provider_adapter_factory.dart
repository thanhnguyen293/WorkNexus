import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import 'github/github_adapter.dart';
import 'github/github_client.dart';
import 'gitlab/gitlab_adapter.dart';
import 'gitlab/gitlab_client.dart';
import 'zentao/zentao_adapter.dart';
import 'zentao/zentao_client.dart';

/// Builds a live [ProviderAdapter] for a configured account + its secret.
/// Returns null for providers not yet implemented (Jira).
///
/// [zenClient] lets the caller inject a shared [ZenTaoClient] instead of minting
/// a throwaway one. ZenTao rotates (and invalidates) its session id on every
/// login, so two clients for the same account fighting over the session would
/// churn the token — callers that also load session-protected assets (inline
/// images, attachments) MUST pass the same pooled client the asset loader uses.
ProviderAdapter? buildProviderAdapter(
  Account account,
  String secret, {
  ZenTaoClient? zenClient,
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
        client: GitLabClient(baseUrl: account.baseUrl ?? '', token: secret),
      );
    case ProviderType.github:
      return GitHubAdapter(
        accountId: account.id,
        client: GitHubClient(baseUrl: account.baseUrl ?? '', token: secret),
      );
    case ProviderType.jira:
      return null;
  }
}
