import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/domain/value_objects/provider_type.dart';
import 'zentao/zentao_adapter.dart';
import 'zentao/zentao_client.dart';

/// Builds a live [ProviderAdapter] for a configured account + its secret.
/// Returns null for providers not yet implemented (GitHub/GitLab/Jira).
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
    case ProviderType.github:
    case ProviderType.gitlab:
    case ProviderType.jira:
      return null;
  }
}
