import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/workspace_overview/domain/entities/assigned_work_item.dart';
import 'package:work_nexus/features/workspace_overview/domain/usecases/list_assigned_work.dart';

const _accZenTao = Account(
  id: 'acc-zt',
  workspaceId: 'ws-1',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);

const _accGh1 = Account(
  id: 'acc-gh-1',
  workspaceId: 'ws-1',
  providerType: ProviderType.github,
  handle: 'octocat',
);

const _accGh2 = Account(
  id: 'acc-gh-2',
  workspaceId: 'ws-1',
  providerType: ProviderType.github,
  handle: 'mona',
);

const _accGl = Account(
  id: 'acc-gl',
  workspaceId: 'ws-1',
  providerType: ProviderType.gitlab,
  handle: 'tanuki',
);

Ticket _makeTicket({
  required String id,
  String accountId = 'acc-zt',
  ProviderType provider = ProviderType.zentao,
  String externalKey = '1',
  String? externalType = 'Task',
  String title = 'Test Ticket',
  String? assignee = 'thanh',
  UnifiedStatus status = UnifiedStatus.inprogress,
  String providerStatus = 'wait',
  DateTime? updatedAt,
  List<String> labels = const [],
  TicketProviderEntity? providerEntity,
}) {
  return Ticket(
    id: id,
    accountId: accountId,
    projectId: 'p1',
    providerType: provider,
    externalKey: externalKey,
    externalType: externalType,
    title: title,
    body: 'Body',
    priority: Priority.medium,
    status: status,
    providerStatus: providerStatus,
    sourceHash: 'h_$id',
    assignee: assignee,
    labels: labels,
    updatedAt: updatedAt,
    providerEntity: providerEntity,
  );
}

void main() {
  const useCase = ListAssignedWork();
  final now = DateTime(2026, 10, 14, 12);

  group('ListAssignedWork', () {
    test('returns empty when no accounts provided', () {
      final t = _makeTicket(id: 't1');
      final result = useCase(
        ListAssignedWorkInput(tickets: [t], accounts: const [], now: now),
      );
      expect(result, isEmpty);
    });

    test('returns empty when tickets list is empty', () {
      final result = useCase(
        ListAssignedWorkInput(
          tickets: const [],
          accounts: const [_accZenTao],
          now: now,
        ),
      );
      expect(result, isEmpty);
    });

    test('skips ticket with null assignee and no reviewers', () {
      final t = _makeTicket(id: 't1', assignee: null);
      final result = useCase(
        ListAssignedWorkInput(
          tickets: [t],
          accounts: const [_accZenTao],
          now: now,
        ),
      );
      expect(result, isEmpty);
    });

    test('case-insensitive handle match for assignee', () {
      final t1 = _makeTicket(
        id: 't1',
        assignee: 'THANH',
        title: 'Task Alpha',
        externalKey: '10',
      );
      final t2 = _makeTicket(
        id: 't2',
        assignee: 'Thanh ',
        title: 'Task Beta',
        externalKey: '11',
      );
      final result = useCase(
        ListAssignedWorkInput(
          tickets: [t1, t2],
          accounts: const [_accZenTao],
          now: now,
        ),
      );
      expect(result.length, 2);
      expect(result[0].title, 'Task Alpha');
      expect(result[0].reason, AssignedReason.assignee);
      expect(result[0].displayKey, 'TASK-10');
      expect(result[1].title, 'Task Beta');
    });

    test('excludes closed and finished items', () {
      final openTask = _makeTicket(id: 't1');
      final doneUnified = _makeTicket(id: 't2', status: UnifiedStatus.done);
      final ztDoneRaw = _makeTicket(id: 't3', providerStatus: 'done');
      final ztClosedRaw = _makeTicket(id: 't4', providerStatus: 'closed');
      final ztResolvedRaw = _makeTicket(id: 't5', providerStatus: 'resolved');
      final ztCancelRaw = _makeTicket(id: 't6', providerStatus: 'cancel');
      final ghMerged = _makeTicket(
        id: 't7',
        accountId: 'acc-gh-1',
        provider: ProviderType.github,
        assignee: 'octocat',
        providerEntity: const TicketProviderEntity.githubItem(merged: true),
      );

      final result = useCase(
        ListAssignedWorkInput(
          tickets: [
            openTask,
            doneUnified,
            ztDoneRaw,
            ztClosedRaw,
            ztResolvedRaw,
            ztCancelRaw,
            ghMerged,
          ],
          accounts: const [_accZenTao, _accGh1],
          now: now,
        ),
      );

      expect(result.map((i) => i.ticketId), ['t1']);
    });

    test('matches reviewer reason for GitHub PR and GitLab MR', () {
      final ghPr = _makeTicket(
        id: 'gh-pr-1',
        accountId: 'acc-gh-1',
        provider: ProviderType.github,
        externalKey: '42',
        externalType: 'PullRequest',
        assignee: 'someone_else',
        providerEntity: const TicketProviderEntity.githubItem(
          reviewers: ['OCTOCAT', 'other_dev'],
        ),
      );

      final glMr = _makeTicket(
        id: 'gl-mr-1',
        accountId: 'acc-gl',
        provider: ProviderType.gitlab,
        externalKey: '99',
        externalType: 'MergeRequest',
        assignee: null,
        providerEntity: const TicketProviderEntity.gitlabItem(
          reviewers: ['tanuki'],
        ),
      );

      final result = useCase(
        ListAssignedWorkInput(
          tickets: [ghPr, glMr],
          accounts: const [_accGh1, _accGl],
          now: now,
        ),
      );

      expect(result.length, 2);
      final ghItem = result.firstWhere((i) => i.ticketId == 'gh-pr-1');
      expect(ghItem.reason, AssignedReason.reviewer);
      expect(ghItem.displayKey, '#42');

      final glItem = result.firstWhere((i) => i.ticketId == 'gl-mr-1');
      expect(glItem.reason, AssignedReason.reviewer);
      expect(glItem.displayKey, '!99');
    });

    test('assignee takes precedence over reviewer if user is both', () {
      final pr = _makeTicket(
        id: 'gh-pr-both',
        accountId: 'acc-gh-1',
        provider: ProviderType.github,
        assignee: 'octocat',
        providerEntity: const TicketProviderEntity.githubItem(
          reviewers: ['octocat'],
        ),
      );

      final result = useCase(
        ListAssignedWorkInput(
          tickets: [pr],
          accounts: const [_accGh1],
          now: now,
        ),
      );

      expect(result.single.reason, AssignedReason.assignee);
    });

    test('handles multiple accounts of the same provider', () {
      final t1 = _makeTicket(
        id: 'gh-1',
        accountId: 'acc-gh-1',
        provider: ProviderType.github,
        assignee: 'octocat',
        title: 'Octocat work',
      );
      final t2 = _makeTicket(
        id: 'gh-2',
        accountId: 'acc-gh-2',
        provider: ProviderType.github,
        assignee: 'mona',
        title: 'Mona work',
      );
      final t3 = _makeTicket(
        id: 'gh-3',
        accountId: 'acc-gh-1',
        provider: ProviderType.github,
        assignee: 'mona', // Wrong account for mona
        title: 'Mona on octocat account',
      );

      final result = useCase(
        ListAssignedWorkInput(
          tickets: [t1, t2, t3],
          accounts: const [_accGh1, _accGh2],
          now: now,
        ),
      );

      expect(
        result.map((i) => i.title),
        containsAll(['Octocat work', 'Mona work']),
      );
      expect(result.any((i) => i.title == 'Mona on octocat account'), isFalse);
    });

    test('formats displayKey according to provider and externalType', () {
      final bug = _makeTicket(id: '1', externalKey: '101', externalType: 'Bug');
      final task = _makeTicket(id: '2', externalKey: '102');
      final story = _makeTicket(
        id: '3',
        externalKey: '103',
        externalType: 'Story',
      );
      final glMr = _makeTicket(
        id: '4',
        accountId: 'acc-gl',
        provider: ProviderType.gitlab,
        externalKey: '201',
        externalType: 'MergeRequest',
        assignee: 'tanuki',
      );
      final glIssue = _makeTicket(
        id: '5',
        accountId: 'acc-gl',
        provider: ProviderType.gitlab,
        externalKey: '202',
        externalType: 'Issue',
        assignee: 'tanuki',
      );
      final ghIssue = _makeTicket(
        id: '6',
        accountId: 'acc-gh-1',
        provider: ProviderType.github,
        externalKey: '301',
        assignee: 'octocat',
      );

      final result = useCase(
        ListAssignedWorkInput(
          tickets: [bug, task, story, glMr, glIssue, ghIssue],
          accounts: const [_accZenTao, _accGl, _accGh1],
          now: now,
        ),
      );

      expect(result.firstWhere((i) => i.ticketId == '1').displayKey, 'BUG-101');
      expect(
        result.firstWhere((i) => i.ticketId == '2').displayKey,
        'TASK-102',
      );
      expect(
        result.firstWhere((i) => i.ticketId == '3').displayKey,
        'STORY-103',
      );
      expect(result.firstWhere((i) => i.ticketId == '4').displayKey, '!201');
      expect(result.firstWhere((i) => i.ticketId == '5').displayKey, '#202');
      expect(result.firstWhere((i) => i.ticketId == '6').displayKey, '#301');
    });

    test('sorts by overdue first -> due asc -> updatedAt desc', () {
      final overdueEarlier = _makeTicket(
        id: 'overdue-1',
        title: 'Overdue Earlier',
        labels: ['deadline:2026-10-10'],
      );
      final overdueLater = _makeTicket(
        id: 'overdue-2',
        title: 'Overdue Later',
        labels: ['deadline:2026-10-12'],
      );
      final upcomingEarlier = _makeTicket(
        id: 'upcoming-1',
        title: 'Upcoming Earlier',
        labels: ['due:2026-10-16'],
      );
      final upcomingLater = _makeTicket(
        id: 'upcoming-2',
        title: 'Upcoming Later',
        labels: ['deadline:2026-10-20'],
      );
      final noDueRecent = _makeTicket(
        id: 'no-due-1',
        title: 'No Due Recent',
        updatedAt: DateTime(2026, 10, 14, 10),
      );
      final noDueOlder = _makeTicket(
        id: 'no-due-2',
        title: 'No Due Older',
        updatedAt: DateTime(2026, 10, 13, 10),
      );

      final result = useCase(
        ListAssignedWorkInput(
          tickets: [
            noDueOlder,
            upcomingLater,
            overdueLater,
            noDueRecent,
            overdueEarlier,
            upcomingEarlier,
          ],
          accounts: const [_accZenTao],
          now: now,
        ),
      );

      expect(result.map((i) => i.ticketId), [
        'overdue-1',
        'overdue-2',
        'upcoming-1',
        'upcoming-2',
        'no-due-1',
        'no-due-2',
      ]);
    });
  });
}
