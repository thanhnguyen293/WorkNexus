import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/usecases/filter_tickets.dart';

Ticket _t(String id) => Ticket(
  id: id,
  accountId: 'zt',
  projectId: 'p',
  providerType: ProviderType.zentao,
  externalKey: id,
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'wait',
  sourceHash: 'h',
);

BoardQuery _q(List<Ticket> tickets, {DateTime? now}) => BoardQuery(
  tickets: tickets,
  filter: const FilterState(),
  accountWorkspace: const {'zt': 'compB'},
  workspaceOrder: const ['compB'],
  now: now ?? DateTime(2026, 7, 17, 12),
);

void main() {
  test('two queries over equal inputs are equal', () {
    final a = _q([_t('1'), _t('2')]);
    final b = _q([_t('1'), _t('2')]);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a changed ticket, order or time makes them differ', () {
    final base = _q([_t('1'), _t('2')]);
    expect(base, isNot(_q([_t('1'), _t('2').copyWith(title: 'x')])));
    expect(base, isNot(_q([_t('2'), _t('1')])));
    expect(base, isNot(_q([_t('1'), _t('2')], now: DateTime(2026, 7, 17, 13))));
  });
}
