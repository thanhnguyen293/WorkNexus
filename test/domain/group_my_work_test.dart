import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/dashboard/domain/usecases/group_my_work.dart';

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
  test('orders sections by what needs the assignee first', () {
    final groups = const GroupMyWork()([
      _t('1', UnifiedStatus.done, Priority.medium),
      _t('2', UnifiedStatus.review, Priority.medium),
      _t('3', UnifiedStatus.todo, Priority.medium),
      _t('4', UnifiedStatus.inprogress, Priority.medium),
      _t('5', UnifiedStatus.inbox, Priority.medium),
      _t('6', UnifiedStatus.blocked, Priority.medium),
    ]);
    expect(groups.map((g) => g.status), [
      UnifiedStatus.inprogress,
      UnifiedStatus.todo,
      UnifiedStatus.inbox,
      UnifiedStatus.blocked,
      UnifiedStatus.review,
      UnifiedStatus.done,
    ]);
  });

  test('leaves out empty sections and sorts urgent, then newest first', () {
    final groups = const GroupMyWork()([
      _t('10', UnifiedStatus.todo, Priority.low),
      _t('30', UnifiedStatus.todo, Priority.low),
      _t('5', UnifiedStatus.todo, Priority.urgent),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.tickets.map((t) => t.id), ['5', '30', '10']);
  });

  test('an empty list has no sections', () {
    expect(const GroupMyWork()(const []), isEmpty);
  });
}
