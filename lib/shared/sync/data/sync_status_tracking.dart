import 'dart:io';

import '../../../core/domain/repositories/sync_status_repository.dart';
import '../../../core/domain/value_objects/account_sync_status.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';

/// Runs [action] (a sync for [accountId]) and reports the account's sync
/// status to [repo] around it — syncing, then idle / offline / authExpired /
/// error — so the auth-expired banner and the integration rows follow it.
Future<T> trackSyncStatus<T>(
  SyncStatusRepository? repo,
  String accountId,
  Future<T> Function() action,
) async {
  if (repo == null) return action();
  repo.report(accountId, const AccountSyncStatus.syncing());
  try {
    final result = await action();
    repo.report(accountId, switch (result) {
      Err(:final failure) => switch (failure) {
        AuthFailure() => const AccountSyncStatus.authExpired(),
        NetworkFailure() => const AccountSyncStatus.offline(),
        _ => AccountSyncStatus.error(failure.message),
      },
      _ => AccountSyncStatus.idle(lastSyncedAt: DateTime.now()),
    });
    return result;
  } on SocketException {
    repo.report(accountId, const AccountSyncStatus.offline());
    rethrow;
  } catch (e) {
    repo.report(accountId, AccountSyncStatus.error(e.toString()));
    rethrow;
  }
}
