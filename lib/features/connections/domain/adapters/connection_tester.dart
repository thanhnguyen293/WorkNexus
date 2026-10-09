import '../../../../core/domain/adapters/provider_adapter.dart';
import '../../../../core/domain/entities/account.dart';
import '../../../../core/error/result.dart';

/// Checks a not-yet-saved account's credentials against its provider before
/// it is stored (and resolves the server's real base URL on the way).
/// Implemented in the data layer.
abstract interface class ConnectionTester {
  Future<Result<ConnectionCheck>> test(Account account, String secret);
}
