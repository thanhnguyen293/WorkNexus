import '../entities/dashboard_execution.dart';

/// The executions worth a glance first: running ones before the rest, then
/// the soonest to end (undated last), at most [limit].
class RankDashboardExecutions {
  const RankDashboardExecutions();

  List<DashboardExecution> call(
    Iterable<DashboardExecution> executions, {
    int limit = 3,
  }) {
    final sorted = executions.toList()
      ..sort((a, b) {
        final byRunning = _rank(a).compareTo(_rank(b));
        if (byRunning != 0) return byRunning;
        final aEnd = a.end;
        final bEnd = b.end;
        if (aEnd == null || bEnd == null) {
          return (aEnd == null ? 1 : 0) - (bEnd == null ? 1 : 0);
        }
        return aEnd.compareTo(bEnd);
      });
    return sorted.take(limit).toList();
  }

  static int _rank(DashboardExecution e) => e.status == 'doing' ? 0 : 1;
}
