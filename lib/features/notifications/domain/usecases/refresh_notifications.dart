import '../../../../core/error/result.dart';
import '../repositories/notification_repository.dart';

/// Refreshes the notifications of several accounts at once. One account
/// failing does not stop the others; the first failure is returned.
class RefreshNotifications {
  const RefreshNotifications(this._repository);

  final NotificationRepository _repository;

  Future<Result<void>> call(Iterable<String> accountIds) async {
    final results = await Future.wait([
      for (final id in accountIds) _repository.refresh(id),
    ]);
    for (final r in results) {
      if (r case Err(:final failure)) return Err(failure);
    }
    return const Ok(null);
  }
}
