import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/shared/board/domain/usecases/is_assigned_to_me.dart';

const _me = Account(
  id: 'zt',
  workspaceId: 'ws',
  providerType: ProviderType.zentao,
  handle: 'thanh.nguyen',
);

Ticket _assignedTo(String? assignee) => Ticket(
  id: 'zt:bug:1',
  accountId: 'zt',
  projectId: 'zt:p',
  providerType: ProviderType.zentao,
  externalKey: '1',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: 'h',
  assignee: assignee,
);

void main() {
  const isMine = IsAssignedToMe();

  test('the handle matches, whatever its separators', () {
    expect(isMine(_assignedTo('Thanh.Nguyen'), _me), isTrue);
    expect(isMine(_assignedTo('thanh_nguyen'), _me), isTrue);
  });

  test('a name that only starts or ends alike is someone else', () {
    expect(isMine(_assignedTo('thanh.nguyen2'), _me), isFalse);
    expect(isMine(_assignedTo('thanh'), _me), isFalse);
    expect(isMine(_assignedTo('-'), _me), isFalse);
  });
}
