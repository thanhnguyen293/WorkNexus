import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/tools/gitlab/data/datasources/gitlab_client.dart';
import 'package:work_nexus/tools/gitlab/data/models/gitlab_models.dart';
import 'package:work_nexus/tools/gitlab/data/repositories/gitlab_adapter.dart';

class _MockGitLabClient extends Mock implements GitLabClient {}

const _issue = Ticket(
  id: 'gl-a:x',
  accountId: 'gl-a',
  projectId: 'gl-a:group/web',
  providerType: ProviderType.gitlab,
  externalKey: '42',
  externalType: 'Issue',
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'opened',
  sourceHash: 'h',
);

void main() {
  late _MockGitLabClient client;
  late GitLabAdapter adapter;

  setUp(() {
    client = _MockGitLabClient();
    adapter = GitLabAdapter(accountId: 'gl-a', client: client);
  });

  test('comments and activity share one notes request', () async {
    when(() => client.issueNotes(any(), any())).thenAnswer(
      (_) async => [
        const GitLabNote(id: 1, body: 'looks good'),
        const GitLabNote(id: 2, body: 'assigned to @me', system: true),
      ],
    );

    final comments = await adapter.listComments(_issue);
    final activity = await adapter.listActivity(_issue);

    expect((comments as Ok).value, hasLength(1));
    expect((activity as Ok).value, hasLength(1));
    verify(() => client.issueNotes(any(), any())).called(1);
  });

  test('a failed notes request is asked again', () async {
    var calls = 0;
    when(() => client.issueNotes(any(), any())).thenAnswer((_) async {
      if (++calls == 1) throw StateError('down');
      return [const GitLabNote(id: 1, body: 'back')];
    });

    expect(await adapter.listComments(_issue), isA<Err<Object?>>());
    expect((await adapter.listComments(_issue) as Ok).value, hasLength(1));
    verify(() => client.issueNotes(any(), any())).called(2);
  });
}
