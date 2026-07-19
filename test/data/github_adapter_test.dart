import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/adapters/provider_adapter.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/connections/data/github/github_adapter.dart';
import 'package:work_nexus/features/connections/data/github/github_client.dart';
import 'package:work_nexus/features/connections/data/github/github_models.dart';
import 'package:work_nexus/features/connections/data/github/github_normalize.dart';

class _MockGitHubClient extends Mock implements GitHubClient {}

Ticket _ticket({required String externalType, String key = '42'}) => Ticket(
  id: 'gh-a:x',
  accountId: 'gh-a',
  projectId: 'gh-a:octo/web',
  providerType: ProviderType.github,
  externalKey: key,
  externalType: externalType,
  title: 't',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'open',
  sourceHash: 'h',
);

void main() {
  late _MockGitHubClient client;
  late GitHubAdapter adapter;

  setUp(() {
    client = _MockGitHubClient();
    adapter = GitHubAdapter(accountId: 'gh-a', client: client);
  });

  // The repo ref parsed from projectId `gh-a:octo/web` — GitHub takes the slash
  // literally, so it is NOT URL-encoded (unlike GitLab's numeric/encoded ref).
  const ref = 'octo/web';

  test('closeItem sets state=closed on the issues endpoint', () async {
    when(
      () => client.updateIssue(any(), any(), state: any(named: 'state')),
    ).thenAnswer((_) async {});

    final res = await adapter.closeItem(_ticket(externalType: 'Issue'));

    expect(res, isA<Ok<bool>>());
    verify(() => client.updateIssue(ref, '42', state: 'closed')).called(1);
  });

  test('reopenItem sets state=open', () async {
    when(
      () => client.updateIssue(any(), any(), state: any(named: 'state')),
    ).thenAnswer((_) async {});

    await adapter.reopenItem(_ticket(externalType: 'Issue'));

    verify(() => client.updateIssue(ref, '42', state: 'open')).called(1);
  });

  test('closeItem closes a PR via the same issues endpoint', () async {
    when(
      () => client.updateIssue(any(), any(), state: any(named: 'state')),
    ).thenAnswer((_) async {});

    await adapter.closeItem(_ticket(externalType: 'PullRequest'));

    verify(() => client.updateIssue(ref, '42', state: 'closed')).called(1);
  });

  test('mergePull calls the merge endpoint', () async {
    when(
      () => client.mergePull(
        any(),
        any(),
        mergeMethod: any(named: 'mergeMethod'),
      ),
    ).thenAnswer((_) async {});

    final res = await adapter.mergePull(_ticket(externalType: 'PullRequest'));

    expect(res, isA<Ok<bool>>());
    verify(() => client.mergePull(ref, '42', mergeMethod: 'merge')).called(1);
  });

  test('listRepoAssignees maps, dedupes, and sorts by login', () async {
    when(() => client.assignees(ref)).thenAnswer(
      (_) async => const [
        GitHubUser(login: 'zoe', name: 'Zoe'),
        GitHubUser(login: 'amy', name: 'Amy'),
        GitHubUser(login: 'amy', name: 'Amy'), // duplicate
        GitHubUser(login: '', name: 'No login'), // dropped
      ],
    );

    final res = await adapter.listRepoAssignees(_ticket(externalType: 'Issue'));

    final users = (res as Ok<List<ProviderUser>>).value;
    expect(users.map((u) => u.account), ['amy', 'zoe']); // deduped + sorted
    expect(users.first.displayName, 'Amy');
  });

  test('listRepoItems normalizes PRs for the pullRequest kind', () async {
    when(
      () => client.repoPulls(
        ref,
        state: any(named: 'state'),
        sort: any(named: 'sort'),
        direction: any(named: 'direction'),
        maxPages: any(named: 'maxPages'),
      ),
    ).thenAnswer((_) async => const [GitHubPull(number: 7, state: 'open')]);

    final res = await adapter.listRepoItems(ref, kind: GitHubKind.pullRequest);

    final tickets = (res as Ok<List<Ticket>>).value;
    expect(tickets, hasLength(1));
    expect(tickets.first.externalType, 'PullRequest');
    expect(tickets.first.externalKey, '7');
  });
}
