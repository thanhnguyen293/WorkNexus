import '../../../../core/error/result.dart';
import '../entities/zentao_dashboard.dart';

/// The ZenTao dashboard of an account. Local-first: [watch] reads the stored
/// snapshot, [refresh] fetches a new one from the server and stores it.
abstract interface class DashboardRepository {
  /// The stored dashboard of [accountId] (null until first fetched), live.
  Stream<ZenTaoDashboard?> watch(String accountId);

  /// The stored dashboard of [accountId], once.
  Future<ZenTaoDashboard?> cached(String accountId);

  /// Fetches the dashboard of [accountId] from ZenTao and stores it.
  Future<Result<void>> refresh(String accountId);

  /// Fetches every bug and task assigned to the account's user (all pages)
  /// into the shared ticket store, where the full "my work" lists read them.
  Future<Result<void>> syncAssignedWork(String accountId);
}
