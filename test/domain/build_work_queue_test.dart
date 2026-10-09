import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/dashboard/domain/usecases/build_work_queue.dart';

Ticket _t(String id, UnifiedStatus status, Priority priority) => Ticket(
  id: id,
  accountId: 'a1',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  title: id,
  body: '',
  priority: priority,
  status: status,
  providerStatus: '',
  sourceHash: '',
);

void main() {
  test('splits in-progress from not started, urgent then newest first', () {
    final q = const BuildWorkQueue()([
      _t('10', UnifiedStatus.todo, Priority.medium),
      _t('20', UnifiedStatus.inprogress, Priority.low),
      _t('5', UnifiedStatus.inbox, Priority.urgent),
      _t('30', UnifiedStatus.todo, Priority.medium),
      _t('40', UnifiedStatus.inprogress, Priority.high),
    ]);
    expect(q.inProgress.map((t) => t.id), ['40', '20']);
    expect(q.notStarted.map((t) => t.id), ['5', '30', '10']);
  });
}
