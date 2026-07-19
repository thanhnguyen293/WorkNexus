import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_adapter.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_client.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_models.dart';
import 'package:work_nexus/features/connections/data/gitlab/gitlab_normalize.dart';

class _MockGitLabClient extends Mock implements GitLabClient {}

Ticket _ticket({required String externalType, String key = '42'}) => Ticket(
  id: 'gl-a:x',
  accountId: 'gl-a',
  projectId: 'gl-a:group/web',
  providerType: ProviderType.gitlab,
  externalKey: key,
  externalType: externalType,
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

  // The URL-encoded project ref parsed from projectId `gl-a:group/web`.
  const ref = 'group%2Fweb';

  test('closeIssue sends state_event=close on the issue endpoint', () async {
    when(
      () => client.updateIssue(
        any(),
        any(),
        stateEvent: any(named: 'stateEvent'),
      ),
    ).thenAnswer((_) async {});

    final res = await adapter.closeIssue(_ticket(externalType: 'Issue'));

    expect(res, isA<Ok<bool>>());
    verify(() => client.updateIssue(ref, '42', stateEvent: 'close')).called(1);
  });

  test('reopenIssue sends state_event=reopen', () async {
    when(
      () => client.updateIssue(
        any(),
        any(),
        stateEvent: any(named: 'stateEvent'),
      ),
    ).thenAnswer((_) async {});

    await adapter.reopenIssue(_ticket(externalType: 'Issue'));

    verify(() => client.updateIssue(ref, '42', stateEvent: 'reopen')).called(1);
  });

  test(
    'closeMergeRequest sends state_event=close on the MR endpoint',
    () async {
      when(
        () => client.updateMergeRequest(
          any(),
          any(),
          stateEvent: any(named: 'stateEvent'),
        ),
      ).thenAnswer((_) async {});

      await adapter.closeMergeRequest(_ticket(externalType: 'MergeRequest'));

      verify(
        () => client.updateMergeRequest(ref, '42', stateEvent: 'close'),
      ).called(1);
    },
  );

  test('mergeMergeRequest calls the merge endpoint', () async {
    when(() => client.mergeMergeRequest(any(), any())).thenAnswer((_) async {});

    final res = await adapter.mergeMergeRequest(
      _ticket(externalType: 'MergeRequest'),
    );

    expect(res, isA<Ok<bool>>());
    verify(() => client.mergeMergeRequest(ref, '42')).called(1);
  });

  test('listProjectMembers maps, dedupes, and sorts members', () async {
    when(() => client.members(ref)).thenAnswer(
      (_) async => const [
        GitLabUser(id: 2, username: 'zoe', name: 'Zoe'),
        GitLabUser(id: 1, username: 'amy', name: 'Amy'),
        GitLabUser(
          id: 1,
          username: 'amy',
          name: 'Amy',
        ), // duplicate (inherited)
        GitLabUser(id: 3, username: '', name: 'No login'), // dropped
      ],
    );

    final res = await adapter.listProjectMembers(
      _ticket(externalType: 'Issue'),
    );

    final users = (res as Ok<List<ProviderUser>>).value;
    expect(users.map((u) => u.account), ['amy', 'zoe']); // deduped + sorted
    expect(users.first.displayName, 'Amy');
  });

  test('listProjectItems normalizes MRs for the merge-request kind', () async {
    when(
      () => client.projectMergeRequests(
        ref,
        state: any(named: 'state'),
        orderBy: any(named: 'orderBy'),
        sort: any(named: 'sort'),
        maxPages: any(named: 'maxPages'),
      ),
    ).thenAnswer(
      (_) async => const [
        GitLabMergeRequest(id: 9, iid: 7, projectId: 3, state: 'opened'),
      ],
    );

    final res = await adapter.listProjectItems(
      ref,
      kind: GitLabKind.mergeRequest,
    );

    final tickets = (res as Ok<List<Ticket>>).value;
    expect(tickets, hasLength(1));
    expect(tickets.first.externalType, 'MergeRequest');
    expect(tickets.first.externalKey, '7');
  });
}
