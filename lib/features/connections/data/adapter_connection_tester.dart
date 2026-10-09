import '../../../core/domain/adapters/provider_adapter.dart';
import '../../../core/domain/entities/account.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/adapters/connection_tester.dart';
import 'provider_adapter_factory.dart';

/// [ConnectionTester] backed by a throwaway provider adapter.
class AdapterConnectionTester implements ConnectionTester {
  const AdapterConnectionTester();

  @override
  Future<Result<ConnectionCheck>> test(Account account, String secret) async {
    final adapter = buildProviderAdapter(account, secret);
    if (adapter == null) {
      return Err(
        UnexpectedFailure('${account.providerType.name} is not supported'),
      );
    }
    return adapter.testConnection();
  }
}
