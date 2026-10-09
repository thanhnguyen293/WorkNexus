import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/zentao_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_local_datasource.dart';
import '../mappers/zentao_notification_mapper.dart';

/// Fetches the raw ZenTao notification-menu view of an account.
typedef ZenTaoMessagesFetcher =
    Future<Result<Map<String, dynamic>>> Function(String accountId);

/// Runs a ZenTao message action (e.g. `ajaxMarkRead-12`) for an account.
typedef ZenTaoMessageActionRunner =
    Future<Result<void>> Function(String accountId, String action);

/// [NotificationRepository] over ZenTao's classic message actions, stored in
/// drift. Commands update the store first so the UI reacts at once; when the
/// server refuses, the account is refetched to undo the optimistic change.
class ZenTaoNotificationRepository implements NotificationRepository {
  const ZenTaoNotificationRepository({
    required NotificationLocalDatasource local,
    required ZenTaoMessagesFetcher fetch,
    required ZenTaoMessageActionRunner run,
  }) : _local = local,
       _fetch = fetch,
       _run = run;

  final NotificationLocalDatasource _local;
  final ZenTaoMessagesFetcher _fetch;
  final ZenTaoMessageActionRunner _run;

  @override
  Stream<List<ZenTaoNotification>> watchAll() => _local.watchAll().map(
    (rows) => [for (final r in rows) zenTaoNotificationFromRow(r)],
  );

  @override
  Future<Result<void>> refresh(String accountId) async {
    final res = await _fetch(accountId);
    switch (res) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final items = zenTaoNotificationsFromView(value, accountId: accountId);
        return _store(
          () => _local.replaceAccount(accountId, [
            for (final n in items) zenTaoNotificationToCompanion(n),
          ]),
        );
    }
  }

  @override
  Future<Result<void>> markRead(String accountId, {String? id}) => _command(
    accountId,
    () => _local.setRead(accountId, id: id, read: true),
    'ajaxMarkRead-${id ?? 'all'}',
  );

  @override
  Future<Result<void>> markUnread(String accountId, String id) => _command(
    accountId,
    () => _local.setRead(accountId, id: id, read: false),
    'ajaxMarkUnread-$id',
  );

  @override
  Future<Result<void>> delete(String accountId, String id) => _command(
    accountId,
    () => _local.delete(accountId, id: id),
    'ajaxDelete-$id',
  );

  @override
  Future<Result<void>> deleteRead(String accountId) => _command(
    accountId,
    () => _local.delete(accountId, readOnly: true),
    'ajaxDelete-allread',
  );

  Future<Result<void>> _command(
    String accountId,
    Future<void> Function() apply,
    String action,
  ) async {
    final stored = await _store(apply);
    if (stored is Err) return stored;
    final res = await _run(accountId, action);
    if (res case Err(:final failure)) {
      await refresh(accountId);
      return Err(failure);
    }
    return const Ok(null);
  }

  Future<Result<void>> _store(Future<void> Function() write) async {
    try {
      await write();
      return const Ok(null);
    } catch (e) {
      return Err(StorageFailure('Could not store notifications', cause: e));
    }
  }
}
