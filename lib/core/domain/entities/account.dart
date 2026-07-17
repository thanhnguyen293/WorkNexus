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
}
