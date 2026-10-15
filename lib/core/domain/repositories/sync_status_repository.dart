import '../value_objects/account_sync_status.dart';

abstract interface class SyncStatusRepository {
  Stream<AccountSyncStatus> watch(String accountId);
  Future<AccountSyncStatus> getStatus(String accountId);
  void report(String accountId, AccountSyncStatus status);
}
