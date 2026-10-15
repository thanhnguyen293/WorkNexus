import '../entities/account.dart';
import 'provider_adapter.dart';

/// Registry of provider adapters (ZenTao, GitHub, GitLab, etc.).
/// Implemented by the composition root in `app/di/`.
abstract interface class ProviderAdapterRegistry {
  ProviderAdapter? createAdapter(
    Account account,
    String secret, {
    dynamic zenClient,
  });
}
