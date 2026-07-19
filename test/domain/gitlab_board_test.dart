import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/entities/filter_state.dart';
import 'package:work_nexus/features/board/domain/usecases/build_gitlab_issue_board.dart';
import 'package:work_nexus/features/board/domain/usecases/build_gitlab_mr_board.dart';
import 'package:work_nexus/features/board/domain/usecases/filter_tickets.dart';
import 'package:work_nexus/features/board/domain/value_objects/gitlab_issue_column.dart';
import 'package:work_nexus/features/board/domain/value_objects/gitlab_mr_column.dart';

Ticket _mr({
  required String id,
  required String providerStatus,
  UnifiedStatus status = UnifiedStatus.review,
  Priority priority = Priority.medium,
}) => Ticket(
  id: id,
  accountId: 'glA',
  projectId: 'glA:group/web',
  providerType: ProviderType.gitlab,
  externalKey: id,
  externalType: 'MergeRequest',
  title: 'MR $id',
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
  accountId: 'glA',
  projectId: 'glA:group/web',
  providerType: ProviderType.gitlab,
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
  accountWorkspace: const {'glA': 'compA'},
  now: DateTime(2026, 7, 19),
);

void main() {
  group('BuildGitLabMrBoard', () {
    test('groups MRs into draft/review/merged/closed by raw status', () {
      final board = const BuildGitLabMrBoard()(
        _q([
          _mr(id: 'd', providerStatus: 'draft'),
          _mr(id: 'r', providerStatus: 'opened'),
          _mr(id: 'm', providerStatus: 'merged'),
          _mr(id: 'c', providerStatus: 'closed'),
        ]),
      );
      expect(board.column(GitLabMrColumn.draft).tickets.map((t) => t.id), [
        'd',
      ]);
      expect(board.column(GitLabMrColumn.review).tickets.map((t) => t.id), [
        'r',
      ]);
      expect(board.column(GitLabMrColumn.merged).tickets.map((t) => t.id), [
        'm',
      ]);
      expect(board.column(GitLabMrColumn.closed).tickets.map((t) => t.id), [
        'c',
      ]);
      expect(board.total, 4);
    });

    test('sorts a column by priority (urgent first)', () {
      final board = const BuildGitLabMrBoard()(
        _q([
          _mr(id: 'lo', providerStatus: 'opened', priority: Priority.low),
          _mr(id: 'hi', providerStatus: 'opened', priority: Priority.urgent),
        ]),
      );
      expect(board.column(GitLabMrColumn.review).tickets.map((t) => t.id), [
        'hi',
        'lo',
      ]);
    });

    test('excludes issues', () {
      final board = const BuildGitLabMrBoard()(
        _q([_issue(id: 'i', providerStatus: 'opened')]),
      );
      expect(board.total, 0);
    });
  });

  group('BuildGitLabIssueBoard', () {
    test('groups issues into open/inProgress/closed', () {
      final board = const BuildGitLabIssueBoard()(
        _q([
          _issue(id: 'o', providerStatus: 'opened'),
          _issue(
            id: 'p',
            providerStatus: 'opened',
            status: UnifiedStatus.inprogress,
          ),
          _issue(id: 'c', providerStatus: 'closed', status: UnifiedStatus.done),
        ]),
      );
      expect(board.column(GitLabIssueColumn.open).tickets.map((t) => t.id), [
        'o',
      ]);
      expect(
        board.column(GitLabIssueColumn.inProgress).tickets.map((t) => t.id),
        ['p'],
      );
      expect(board.column(GitLabIssueColumn.closed).tickets.map((t) => t.id), [
        'c',
      ]);
    });

    test('excludes merge requests', () {
      final board = const BuildGitLabIssueBoard()(
        _q([_mr(id: 'm', providerStatus: 'opened')]),
      );
      expect(board.total, 0);
    });
  });
}
