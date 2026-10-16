import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/dashboard_execution.dart';
import 'package:work_nexus/features/workspace_overview/domain/usecases/rank_dashboard_executions.dart';

DashboardExecution _e(String id, {String? status, DateTime? end}) =>
    DashboardExecution(id: id, name: id, status: status, end: end);

void main() {
  test('running first, then soonest to end, undated last, capped', () {
    final ranked = const RankDashboardExecutions()([
      _e('waiting-soon', status: 'wait', end: DateTime(2026, 10, 18)),
      _e('doing-late', status: 'doing', end: DateTime(2026, 12, 2)),
      _e('doing-undated', status: 'doing'),
      _e('doing-soon', status: 'doing', end: DateTime(2026, 10, 20)),
      _e('waiting-late', status: 'wait', end: DateTime(2026, 11, 30)),
    ]);

    expect(ranked.map((e) => e.id), [
      'doing-soon',
      'doing-late',
      'doing-undated',
    ]);
  });

  test('keeps every execution under the limit', () {
    final ranked = const RankDashboardExecutions()([
      _e('a', status: 'wait'),
      _e('b', status: 'doing'),
    ], limit: 5);

    expect(ranked.map((e) => e.id), ['b', 'a']);
  });
}
