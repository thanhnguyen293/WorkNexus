import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import 'gitlab/gitlab_adapter.dart';
import 'gitlab/gitlab_client.dart';
import 'zentao/zentao_adapter.dart';
import 'zentao/zentao_client.dart';

/// Builds a live [ProviderAdapter] for a configured account + its secret.
/// Returns null for providers not yet implemented (GitHub/Jira).
ProviderAdapter? buildProviderAdapter(Account account, String secret) {
  switch (account.providerType) {
    case ProviderType.zentao:
      return ZenTaoAdapter(
        accountId: account.id,
        client: ZenTaoClient(
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
    case ProviderType.jira:
      return null;
  }
}
