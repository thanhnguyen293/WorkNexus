import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/provider_type.dart';

part 'account.freezed.dart';

/// A configured provider *connection* — e.g. "a GitHub for Company A" or a
/// ZenTao login. The same [ProviderType] can appear multiple times across
/// workspaces. Secrets are NOT stored here: [credentialsRef] is a key into the
/// OS keychain (flutter_secure_storage).
@freezed
abstract class Account with _$Account {
  const factory Account({
    required String id,
    required String workspaceId,
    required ProviderType providerType,
    required String handle,
    String? baseUrl,
    String? credentialsRef,
  }) = _Account;

  static int _providerOrder(ProviderType p) => switch (p) {
    ProviderType.zentao => 0,
    ProviderType.github => 1,
    ProviderType.gitlab => 2,
    _ => 3,
  };

  /// Sorts [accounts] in rail order: ZenTao first, then GitHub, then GitLab,
  /// then other providers, with secondary ordering by [Account.id].
  static List<Account> sort(List<Account> accounts) {
    return List<Account>.of(accounts)..sort((a, b) {
      final orderA = _providerOrder(a.providerType);
      final orderB = _providerOrder(b.providerType);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.id.compareTo(b.id);
    });
  }
}
