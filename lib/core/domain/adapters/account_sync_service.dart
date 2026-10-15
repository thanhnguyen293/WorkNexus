import '../../error/result.dart';
import '../entities/account.dart';

/// Presentation-facing contract for syncing provider accounts.
abstract interface class AccountSyncService {
  /// Pulls assigned tickets from [account] into drift.
  Future<Result<int>> syncAccount(Account account);

  /// Pulls assigned tickets for [accountId] into drift.
  Future<Result<int>> syncAccountById(String accountId);
}
