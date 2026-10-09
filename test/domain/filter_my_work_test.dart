import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/dashboard/domain/usecases/filter_my_work.dart';
import 'package:work_nexus/features/dashboard/domain/value_objects/dashboard_item_kind.dart';

Ticket _t(
  String id, {
  String account = 'a1',
  String type = 'Task',
  String? assignee = 'thanh',
  UnifiedStatus status = UnifiedStatus.todo,
  String raw = 'wait',
}) => Ticket(
  id: '$account:$id',
  accountId: account,
  projectId: '$account:p',
  providerType: ProviderType.zentao,
  externalKey: id,
  externalType: type,
  title: id,
  body: '',
  priority: Priority.medium,
  status: status,
  providerStatus: raw,
  sourceHash: '',
  assignee: assignee,
);

void main() {
  const filter = FilterMyWork();
  final tickets = [
    _t('9'),
    _t('120'),
    _t('15', assignee: 'Thanh '),
    _t('77', type: 'Bug'),
    _t('50', assignee: 'someone'),
    _t('60', account: 'a2'),
    _t('70', assignee: null),
    _t('8', status: UnifiedStatus.done),
    // A finished task unifies to "review" — still not open work.
    _t('7', status: UnifiedStatus.review, raw: 'done'),
  ];

  test('keeps the kind assigned to the user, highest id first', () {
    final mine = filter(
      tickets,
      accountId: 'a1',
      userAccount: 'thanh',
      kind: DashboardItemKind.task,
    );
    expect(mine.map((t) => t.externalKey), ['120', '15', '9', '8', '7']);
  });

  test('openOnly leaves finished ones out', () {
    final mine = filter(
      tickets,
      accountId: 'a1',
      userAccount: 'thanh',
      kind: DashboardItemKind.task,
      openOnly: true,
    );
    expect(mine.map((t) => t.externalKey), ['120', '15', '9']);
  });

  test('bugs are their own list', () {
    final mine = filter(
      tickets,
      accountId: 'a1',
      userAccount: 'THANH',
      kind: DashboardItemKind.bug,
    );
    expect(mine.map((t) => t.externalKey), ['77']);
  });
}
