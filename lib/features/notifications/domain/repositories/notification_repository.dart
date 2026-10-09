import '../../../../core/error/result.dart';
import '../entities/zentao_notification.dart';

/// ZenTao web notifications. Local-first: [watchAll] reads the stored list,
/// [refresh] replaces an account's list with the server's; the commands change
/// the store first and then the server.
abstract interface class NotificationRepository {
  /// Every stored notification of every account, newest first, live.
  Stream<List<ZenTaoNotification>> watchAll();

  /// Fetches the notifications of [accountId] from ZenTao and stores them.
  Future<Result<void>> refresh(String accountId);

  /// Marks one notification ([id]) or, with null, all of the account's read.
  Future<Result<void>> markRead(String accountId, {String? id});

  Future<Result<void>> markUnread(String accountId, String id);

  Future<Result<void>> delete(String accountId, String id);

  /// Deletes the account's notifications that are already read.
  Future<Result<void>> deleteRead(String accountId);
}
