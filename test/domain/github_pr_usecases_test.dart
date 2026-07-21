import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/adapters/github_pr_service.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/close_github_item.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/merge_github_pr.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/post_github_comment.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/reopen_github_item.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/update_github_pr_branch.dart';

class _MockGitHubPrService extends Mock implements GitHubPrService {}

const _ticket = Ticket(
  id: 'github:pr:7',
  accountId: 'github',
  projectId: 'github:acme/web',
  providerType: ProviderType.github,
  externalKey: '7',
  externalType: 'PullRequest',
  title: 'PR',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'open',
  sourceHash: 'hash',
);

void main() {
  late _MockGitHubPrService service;

  setUp(() => service = _MockGitHubPrService());

  test('PostGitHubComment delegates one comment command', () async {
    when(
      () => service.postComment(_ticket, 'Looks good'),
    ).thenAnswer((_) async => const Ok(null));

    final result = await PostGitHubComment(service)(_ticket, 'Looks good');

    expect(result, isA<Ok<void>>());
    verify(() => service.postComment(_ticket, 'Looks good')).called(1);
  });

  test('CloseGitHubItem delegates one close command', () async {
    when(
      () => service.closeGitHubItem(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await CloseGitHubItem(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.closeGitHubItem(_ticket)).called(1);
  });

  test('ReopenGitHubItem delegates one reopen command', () async {
    when(
      () => service.reopenGitHubItem(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await ReopenGitHubItem(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.reopenGitHubItem(_ticket)).called(1);
  });

  test('MergeGitHubPr delegates one merge command', () async {
    when(
      () => service.mergeGitHubPr(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await MergeGitHubPr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.mergeGitHubPr(_ticket)).called(1);
  });

  test('UpdateGitHubPrBranch delegates one update-branch command', () async {
    when(
      () => service.updateGitHubPrBranch(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await UpdateGitHubPrBranch(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.updateGitHubPrBranch(_ticket)).called(1);
  });
}
