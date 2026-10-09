import '../../../../core/error/result.dart';
import '../repositories/dashboard_repository.dart';

/// Brings an account's dashboard up to date. Opening the dashboard calls it
/// unforced, so a snapshot younger than [maxAge] is shown as is instead of
/// hitting the server on every visit; the refresh button forces it.
class RefreshDashboard {
  const RefreshDashboard(
    this._repository, {
    this.maxAge = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now;

  final DashboardRepository _repository;
  final Duration maxAge;
  final DateTime Function()? _now;

  Future<Result<void>> call(String accountId, {bool force = false}) async {
    if (!force) {
      final cached = await _repository.cached(accountId);
      final now = _now?.call() ?? DateTime.now();
      if (cached != null && now.difference(cached.fetchedAt) < maxAge) {
        return const Ok(null);
      }
    }
    return _repository.refresh(accountId);
  }
}
