import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/usecases/build_github_issue_board.dart';
import 'package:work_nexus/features/board/domain/usecases/build_github_pr_board.dart';
import 'package:work_nexus/features/board/domain/usecases/filter_tickets.dart';
import 'package:work_nexus/features/board/domain/value_objects/github_issue_column.dart';
import 'package:work_nexus/features/board/domain/value_objects/github_pr_column.dart';

Ticket _pr({
  required String id,
  required String providerStatus,
  UnifiedStatus status = UnifiedStatus.review,
  Priority priority = Priority.medium,
}) => Ticket(
  id: id,
  accountId: 'ghA',
  projectId: 'ghA:octo/web',
  providerType: ProviderType.github,
  externalKey: id,
  externalType: 'PullRequest',
  title: 'PR $id',
  body: '',
  priority: priority,
  status: status,
  providerStatus: providerStatus,
  sourceHash: 'h',
);

Ticket _issue({
  required String id,
  required String providerStatus,
  UnifiedStatus status = UnifiedStatus.todo,
}) => Ticket(
  id: id,
  accountId: 'ghA',
  projectId: 'ghA:octo/web',
  providerType: ProviderType.github,
  externalKey: id,
  externalType: 'Issue',
  title: 'Issue $id',
  body: '',
  priority: Priority.medium,
  status: status,
  providerStatus: providerStatus,
  sourceHash: 'h',
);

BoardQuery _q(List<Ticket> tickets) => BoardQuery(
  tickets: tickets,
  filter: const FilterState(),
  accountWorkspace: const {'ghA': 'compA'},
  now: DateTime(2026, 7, 19),
);

void main() {
  group('BuildGitHubPrBoard', () {
    test('groups PRs into draft/review/merged/closed by raw status', () {
      final board = const BuildGitHubPrBoard()(
        _q([
          _pr(id: 'd', providerStatus: 'draft'),
          _pr(id: 'r', providerStatus: 'open'),
          _pr(id: 'm', providerStatus: 'merged'),
          _pr(id: 'c', providerStatus: 'closed'),
        ]),
      );
      expect(board.column(GitHubPrColumn.draft).tickets.map((t) => t.id), [
        'd',
      ]);
      expect(board.column(GitHubPrColumn.review).tickets.map((t) => t.id), [
        'r',
      ]);
      expect(board.column(GitHubPrColumn.merged).tickets.map((t) => t.id), [
        'm',
      ]);
      expect(board.column(GitHubPrColumn.closed).tickets.map((t) => t.id), [
        'c',
      ]);
      expect(board.total, 4);
    });

    test('sorts a column by priority (urgent first)', () {
      final board = const BuildGitHubPrBoard()(
        _q([
          _pr(id: 'lo', providerStatus: 'open', priority: Priority.low),
          _pr(id: 'hi', providerStatus: 'open', priority: Priority.urgent),
        ]),
      );
      expect(board.column(GitHubPrColumn.review).tickets.map((t) => t.id), [
        'hi',
        'lo',
      ]);
    });

    test('excludes issues', () {
      final board = const BuildGitHubPrBoard()(
        _q([_issue(id: 'i', providerStatus: 'open')]),
      );
      expect(board.total, 0);
    });
  });

  group('BuildGitHubIssueBoard', () {
    test('groups issues into open/inProgress/closed', () {
      final board = const BuildGitHubIssueBoard()(
        _q([
          _issue(id: 'o', providerStatus: 'open'),
          _issue(
            id: 'p',
            providerStatus: 'open',
            status: UnifiedStatus.inprogress,
          ),
          _issue(id: 'c', providerStatus: 'closed', status: UnifiedStatus.done),
        ]),
      );
      expect(board.column(GitHubIssueColumn.open).tickets.map((t) => t.id), [
        'o',
      ]);
      expect(
        board.column(GitHubIssueColumn.inProgress).tickets.map((t) => t.id),
        ['p'],
      );
      expect(board.column(GitHubIssueColumn.closed).tickets.map((t) => t.id), [
        'c',
      ]);
    });

    test('excludes pull requests', () {
      final board = const BuildGitHubIssueBoard()(
        _q([_pr(id: 'm', providerStatus: 'open')]),
      );
      expect(board.total, 0);
    });
  });
}
