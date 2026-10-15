import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/tools/gitlab/data/datasources/gitlab_client.dart';
import 'package:work_nexus/tools/gitlab/data/models/gitlab_models.dart';
import 'package:work_nexus/tools/gitlab/data/repositories/gitlab_adapter.dart';

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
    when(
      () => client.mergeMergeRequest(
        any(),
        any(),
        squash: any(named: 'squash'),
        shouldRemoveSourceBranch: any(named: 'shouldRemoveSourceBranch'),
      ),
    ).thenAnswer((_) async {});

    final res = await adapter.mergeMergeRequest(
      _ticket(externalType: 'MergeRequest'),
      squash: true,
      removeSourceBranch: false,
    );

    expect(res, isA<Ok<bool>>());
    verify(
      () => client.mergeMergeRequest(
        ref,
        '42',
        squash: true,
        shouldRemoveSourceBranch: false,
      ),
    ).called(1);
  });

  group('setMergeRequestDraft', () {
    void stubTitle(String title) {
      when(() => client.mergeRequest(ref, '42')).thenAnswer(
        (_) async =>
            GitLabMergeRequest(id: 9, iid: 42, projectId: 3, title: title),
      );
      when(
        () => client.updateMergeRequest(ref, '42', title: any(named: 'title')),
      ).thenAnswer((_) async {});
    }

    test('marking ready strips the draft prefix from the live title', () async {
      stubTitle('Draft: Fix login');

      final res = await adapter.setMergeRequestDraft(
        _ticket(externalType: 'MergeRequest'),
        draft: false,
      );

      expect(res, isA<Ok<bool>>());
      verify(
        () => client.updateMergeRequest(ref, '42', title: 'Fix login'),
      ).called(1);
    });

    test('marking draft adds the prefix once', () async {
      stubTitle('Fix login');

      await adapter.setMergeRequestDraft(
        _ticket(externalType: 'MergeRequest'),
        draft: true,
      );

      verify(
        () => client.updateMergeRequest(ref, '42', title: 'Draft: Fix login'),
      ).called(1);
    });
  });

  group('rebaseMergeRequest', () {
    late GitLabAdapter fast;

    setUp(() {
      fast = GitLabAdapter(
        accountId: 'gl-a',
        client: client,
        rebasePollInterval: Duration.zero,
      );
      when(() => client.rebaseMergeRequest(ref, '42')).thenAnswer((_) async {});
    });

    void stubPolls(List<GitLabMergeRequest> states) {
      when(
        () => client.mergeRequest(ref, '42', includeRebaseInProgress: true),
      ).thenAnswer((_) async => states.removeAt(0));
    }

    test('waits for the background rebase to finish', () async {
      stubPolls([
        const GitLabMergeRequest(
          id: 9,
          iid: 42,
          projectId: 3,
          rebaseInProgress: true,
        ),
        const GitLabMergeRequest(
          id: 9,
          iid: 42,
          projectId: 3,
          rebaseInProgress: false,
        ),
      ]);

      final res = await fast.rebaseMergeRequest(
        _ticket(externalType: 'MergeRequest'),
      );

      expect(res, isA<Ok<bool>>());
      verify(
        () => client.mergeRequest(ref, '42', includeRebaseInProgress: true),
      ).called(2);
    });

    test('reports a failed rebase from its merge error', () async {
      stubPolls([
        const GitLabMergeRequest(
          id: 9,
          iid: 42,
          projectId: 3,
          rebaseInProgress: false,
          mergeError: 'Rebase failed: conflicts',
        ),
      ]);

      final res = await fast.rebaseMergeRequest(
        _ticket(externalType: 'MergeRequest'),
      );

      expect(res.failureOrNull?.message, 'Rebase failed: conflicts');
    });
  });

  test('listProjectMembers maps, dedupes, and sorts members', () async {
    when(() => client.members(ref)).thenAnswer(
      (_) async => const [
        GitLabUser(
          id: 2,
          username: 'zoe',
          name: 'Zoe',
          avatarUrl: 'https://cdn.example.com/zoe.png',
        ),
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
    expect(users.last.avatarUrl, 'https://cdn.example.com/zoe.png');
  });

  test('setLabels replaces MR labels', () async {
    when(
      () =>
          client.updateMergeRequest(any(), any(), labels: any(named: 'labels')),
    ).thenAnswer((_) async {});

    final result = await adapter.setLabels(
      _ticket(externalType: 'MergeRequest'),
      const ['backend', 'review'],
    );

    expect(result, isA<Ok<bool>>());
    verify(
      () => client.updateMergeRequest(
        ref,
        '42',
        labels: const ['backend', 'review'],
      ),
    ).called(1);
  });

  test('setMilestone uses zero to clear an MR milestone', () async {
    when(
      () => client.updateMergeRequest(
        any(),
        any(),
        milestoneId: any(named: 'milestoneId'),
      ),
    ).thenAnswer((_) async {});

    final result = await adapter.setMilestone(
      _ticket(externalType: 'MergeRequest'),
      null,
    );

    expect(result, isA<Ok<bool>>());
    verify(
      () => client.updateMergeRequest(ref, '42', milestoneId: 0),
    ).called(1);
  });

  test('updateTimeTracking sets estimate and adds spent time', () async {
    when(
      () => client.setMergeRequestTimeEstimate(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => client.addMergeRequestSpentTime(any(), any(), any()),
    ).thenAnswer((_) async {});

    final result = await adapter.updateTimeTracking(
      _ticket(externalType: 'MergeRequest'),
      estimate: '2h',
      spent: '30m',
    );

    expect(result, isA<Ok<bool>>());
    verify(() => client.setMergeRequestTimeEstimate(ref, '42', '2h')).called(1);
    verify(() => client.addMergeRequestSpentTime(ref, '42', '30m')).called(1);
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

    final res = await adapter.listProjectItems(ref, mergeRequests: true);

    final tickets = (res as Ok<List<Ticket>>).value;
    expect(tickets, hasLength(1));
    expect(tickets.first.externalType, 'MergeRequest');
    expect(tickets.first.externalKey, '7');
  });

  group('getTicket on a merge request', () {
    void stubMr(String state) {
      when(() => client.mergeRequest(ref, '42')).thenAnswer(
        (_) async => GitLabMergeRequest(
          id: 9,
          iid: 42,
          projectId: 3,
          state: state,
          sourceBranch: 'feature',
          targetBranch: 'develop',
        ),
      );
    }

    void stubApprovals(Future<GitLabMrApprovals> Function() answer) {
      when(
        () => client.mergeRequestApprovals(ref, '42'),
      ).thenAnswer((_) => answer());
    }

    setUp(() => stubApprovals(() async => const GitLabMrApprovals()));

    DioException forbidden() => DioException(
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: 403),
    );

    test('carries who approved into the cached detail', () async {
      stubMr('merged');
      stubApprovals(
        () async => GitLabMrApprovals.fromJson({
          'approved_by': [
            {
              'user': {'id': 2, 'username': 'thanh', 'name': 'Thanh'},
            },
          ],
          'approvals_left': 0,
          'user_has_approved': true,
          'user_can_approve': false,
        }),
      );

      final res = await adapter.getTicket(
        _ticket(externalType: 'MergeRequest'),
      );

      final entity = (res as Ok<Ticket>).value.providerEntity!.toJson();
      expect(entity['approvedBy'], ['Thanh']);
      expect(entity['userHasApproved'], true);
      expect(entity['approvalsLeft'], 0);
    });

    test('still loads when approvals are unavailable', () async {
      stubMr('merged');
      stubApprovals(() => Future.error(forbidden()));

      final res = await adapter.getTicket(
        _ticket(externalType: 'MergeRequest'),
      );

      expect(res, isA<Ok<Ticket>>());
    });

    void stubCompare(Future<int?> Function() answer) {
      when(
        () => client.commitsBehindTarget(
          any(),
          sourceBranch: any(named: 'sourceBranch'),
          targetBranch: any(named: 'targetBranch'),
        ),
      ).thenAnswer((_) => answer());
    }

    test('still loads when compare fails (source branch deleted)', () async {
      stubMr('opened');
      stubCompare(
        () => Future.error(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 404,
            ),
          ),
        ),
      );

      final res = await adapter.getTicket(
        _ticket(externalType: 'MergeRequest'),
      );

      expect(res, isA<Ok<Ticket>>());
    });

    test('skips compare for a merged MR', () async {
      stubMr('merged');
      stubCompare(() async => 3);

      final res = await adapter.getTicket(
        _ticket(externalType: 'MergeRequest'),
      );

      expect(res, isA<Ok<Ticket>>());
      verifyNever(
        () => client.commitsBehindTarget(
          any(),
          sourceBranch: any(named: 'sourceBranch'),
          targetBranch: any(named: 'targetBranch'),
        ),
      );
    });
  });
}
