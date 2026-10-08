import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/chat/domain/usecases/find_linked_ticket.dart';

Ticket _ticket(String key, String type, String url) => Ticket(
  id: 'acc:$key',
  accountId: 'acc',
  projectId: 'acc:p',
  providerType: ProviderType.zentao,
  externalKey: key,
  externalType: type,
  title: 't$key',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.todo,
  providerStatus: 'active',
  sourceHash: '',
  url: url,
);

void main() {
  const find = FindLinkedTicket();
  final tickets = [
    _ticket(
      '6466',
      'Bug',
      'https://zt.example.com:4433/zentao/bug-view-6466.html',
    ),
    _ticket(
      '6466',
      'Task',
      'https://zt.example.com:4433/zentao/task-view-6466.html',
    ),
  ];

  test('matches a PATH_INFO link by type, id and host', () {
    final t = find(
      'https://zt.example.com:4433/zentao/bug-view-6466.html#app=qa',
      tickets,
    );
    expect(t?.externalType, 'Bug');
  });

  test('matches a GET link', () {
    final t = find(
      'https://zt.example.com/zentao/index.php?m=task&f=view&taskID=6466',
      tickets,
    );
    expect(t?.externalType, 'Task');
  });

  test('ignores other hosts, unknown ids and non-ticket links', () {
    expect(
      find('https://other.com/zentao/bug-view-6466.html', tickets),
      isNull,
    );
    expect(
      find('https://zt.example.com/zentao/bug-view-1.html', tickets),
      isNull,
    );
    expect(find('https://github.com/a/b', tickets), isNull);
  });
}
