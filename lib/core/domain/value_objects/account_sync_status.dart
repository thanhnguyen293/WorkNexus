import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_sync_status.freezed.dart';

@freezed
sealed class AccountSyncStatus with _$AccountSyncStatus {
  const factory AccountSyncStatus.idle({DateTime? lastSyncedAt}) = SyncIdle;
  const factory AccountSyncStatus.syncing() = SyncRunning;
  const factory AccountSyncStatus.offline() = SyncOffline;
  const factory AccountSyncStatus.authExpired() = SyncAuthExpired;
  const factory AccountSyncStatus.error(String message) = SyncError;
}
