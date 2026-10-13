import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:work_nexus/core/domain/adapters/gitlab_mr_service.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/core/error/result.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/approve_gitlab_mr.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/close_gitlab_mr.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/merge_gitlab_mr.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/post_gitlab_mr_comment.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/rebase_gitlab_mr.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/reopen_gitlab_mr.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/set_gitlab_mr_draft.dart';
import 'package:work_nexus/features/task_detail/domain/usecases/unapprove_gitlab_mr.dart';

class _MockGitLabMrService extends Mock implements GitLabMrService {}

const _ticket = Ticket(
  id: 'gitlab:mr:42',
  accountId: 'gitlab',
  projectId: 'project',
  providerType: ProviderType.gitlab,
  externalKey: '42',
  externalType: 'MergeRequest',
  title: 'MR',
  body: '',
  priority: Priority.medium,
  status: UnifiedStatus.review,
  providerStatus: 'opened',
  sourceHash: 'hash',
);

void main() {
  late _MockGitLabMrService service;

  setUp(() => service = _MockGitLabMrService());

  test('PostGitLabMrComment delegates one comment command', () async {
    when(
      () => service.postComment(_ticket, 'Looks good'),
    ).thenAnswer((_) async => const Ok(null));

    final result = await PostGitLabMrComment(service)(_ticket, 'Looks good');

    expect(result, isA<Ok<void>>());
    verify(() => service.postComment(_ticket, 'Looks good')).called(1);
  });

  test('CloseGitLabMr delegates one close command', () async {
    when(
      () => service.closeGitLabItem(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await CloseGitLabMr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.closeGitLabItem(_ticket)).called(1);
  });

  test('ApproveGitLabMr delegates one approval command', () async {
    when(
      () => service.approveGitLabMr(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await ApproveGitLabMr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.approveGitLabMr(_ticket)).called(1);
  });

  test('MergeGitLabMr delegates one merge command', () async {
    when(
      () => service.mergeGitLabMr(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await MergeGitLabMr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.mergeGitLabMr(_ticket)).called(1);
  });

  test('RebaseGitLabMr delegates one rebase command', () async {
    when(
      () => service.rebaseGitLabMr(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await RebaseGitLabMr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.rebaseGitLabMr(_ticket)).called(1);
  });

  test('MergeGitLabMr passes the merge options through', () async {
    when(
      () => service.mergeGitLabMr(
        _ticket,
        squash: true,
        removeSourceBranch: true,
      ),
    ).thenAnswer((_) async => const Ok(null));

    final result = await MergeGitLabMr(service)(
      _ticket,
      squash: true,
      removeSourceBranch: true,
    );

    expect(result, isA<Ok<void>>());
    verify(
      () => service.mergeGitLabMr(
        _ticket,
        squash: true,
        removeSourceBranch: true,
      ),
    ).called(1);
  });

  test('UnapproveGitLabMr delegates one revoke command', () async {
    when(
      () => service.unapproveGitLabMr(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await UnapproveGitLabMr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.unapproveGitLabMr(_ticket)).called(1);
  });

  test('ReopenGitLabMr delegates one reopen command', () async {
    when(
      () => service.reopenGitLabItem(_ticket),
    ).thenAnswer((_) async => const Ok(null));

    final result = await ReopenGitLabMr(service)(_ticket);

    expect(result, isA<Ok<void>>());
    verify(() => service.reopenGitLabItem(_ticket)).called(1);
  });

  test('SetGitLabMrDraft delegates the draft flag', () async {
    when(
      () => service.setGitLabMrDraft(_ticket, draft: false),
    ).thenAnswer((_) async => const Ok(null));

    final result = await SetGitLabMrDraft(service)(_ticket, draft: false);

    expect(result, isA<Ok<void>>());
    verify(() => service.setGitLabMrDraft(_ticket, draft: false)).called(1);
  });
}
