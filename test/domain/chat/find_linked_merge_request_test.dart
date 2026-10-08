import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/chat/domain/usecases/find_linked_merge_request.dart';

Ticket _ticket(String id, String? url) => Ticket(
  id: id,
  accountId: 'a',
  projectId: 'a:p',
  providerType: ProviderType.gitlab,
  externalKey: '1',
  title: id,
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'opened',
  sourceHash: '',
  url: url,
);

void main() {
  const find = FindLinkedMergeRequest();
  final tickets = [
    _ticket('issue', 'https://xddlabs.com/root/tbchat/-/issues/3458'),
    _ticket('mr', 'https://xddlabs.com/Root/TBChat/-/merge_requests/3458'),
    _ticket('none', null),
  ];

  test('matches the stored MR by host, project and number', () {
    expect(
      find(
        'https://xddlabs.com/root/tbchat/-/merge_requests/3458/diffs',
        tickets,
      )?.id,
      'mr',
    );
  });

  test('null for another MR or a non-MR link', () {
    expect(
      find('https://xddlabs.com/root/tbchat/-/merge_requests/1', tickets),
      isNull,
    );
    expect(
      find('https://xddlabs.com/root/tbchat/-/issues/3458', tickets),
      isNull,
    );
  });
}
