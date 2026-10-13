import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/core/domain/entities/account.dart';
import 'package:work_nexus/core/domain/entities/provider_entity.dart';
import 'package:work_nexus/core/domain/entities/ticket.dart';
import 'package:work_nexus/core/domain/value_objects/priority.dart';
import 'package:work_nexus/core/domain/value_objects/provider_type.dart';
import 'package:work_nexus/core/domain/value_objects/unified_status.dart';
import 'package:work_nexus/features/board/domain/usecases/count_assigned_to_me.dart';

const _zentao = Account(
  id: 'z',
  workspaceId: 'w',
  providerType: ProviderType.zentao,
  handle: 'thanh',
);
const _gitlab = Account(
  id: 'gl',
  workspaceId: 'w',
  providerType: ProviderType.gitlab,
  handle: 'dyno',
);
const _github = Account(
  id: 'gh',
  workspaceId: 'w2',
  providerType: ProviderType.github,
  handle: 'octo',
);

Ticket _t(
  String id, {
  required Account account,
  required String type,
  required TicketProviderEntity entity,
  String? assignee,
  UnifiedStatus status = UnifiedStatus.todo,
  String raw = 'active',
}) => Ticket(
  id: '${account.id}:$id',
  accountId: account.id,
  projectId: '${account.id}:p',
  providerType: account.providerType,
  externalKey: id,
  externalType: type,
  title: id,
  body: '',
  priority: Priority.medium,
  status: status,
  providerStatus: raw,
  sourceHash: '',
  assignee: assignee,
  providerEntity: entity,
);

Ticket _bug(String id, String product, {String? assignee = 'thanh'}) => _t(
  id,
  account: _zentao,
  type: 'bug',
  assignee: assignee,
  entity: TicketProviderEntity.zentaoBug(product: product),
);

Ticket _task(String id, String execution, String project) => _t(
  id,
  account: _zentao,
  type: 'task',
  assignee: 'Thanh ',
  entity: TicketProviderEntity.zentaoTask(
    execution: execution,
    project: project,
  ),
);

void main() {
  const count = CountAssignedToMe();
  const accounts = [_zentao, _gitlab, _github];

  test('ZenTao rolls bugs and tasks up through their groups', () {
    final c = count(
      tickets: [
        _bug('1', '10'),
        _bug('2', '10'),
        _bug('3', '11'),
        _bug('4', '10', assignee: 'someone'),
        _bug(
          '5',
          '10',
        ).copyWith(status: UnifiedStatus.review, providerStatus: 'resolved'),
        _task('6', '100', '7'),
        _task('8', '101', '7'),
      ],
      accounts: accounts,
    );
    expect(c.zentaoProduct('z', '10'), 2);
    expect(c.zentaoProduct('z', '11'), 1);
    expect(c.zentaoBugs('z'), 3);
    expect(c.zentaoExecution('z', '100'), 1);
    expect(c.zentaoProject('z', '7'), 2);
    expect(c.zentaoTasks('z'), 2);
    expect(c.pinned('z'), 0);
    expect(c.account('z'), 5);
    expect(c.workspace('w'), 5);
    expect(c.total, 5);
  });

  test('pinned leaves count toward Pinned, not their group', () {
    final c = count(
      tickets: [_bug('1', '10'), _bug('2', '11'), _task('3', '100', '7')],
      accounts: accounts,
      pinnedProjects: {'z:10'},
      pinnedExecutions: {'z:100'},
    );
    expect(c.zentaoProduct('z', '10'), 1);
    expect(c.zentaoExecution('z', '100'), 1);
    expect(c.pinned('z'), 2);
    expect(c.zentaoBugs('z'), 1);
    expect(c.zentaoTasks('z'), 0);
    expect(c.zentaoProject('z', '7'), 0);
    expect(c.account('z'), 3);
  });

  test('GitLab and GitHub match the assignee login, not the name', () {
    final c = count(
      tickets: [
        _t(
          'mr1',
          account: _gitlab,
          type: 'MergeRequest',
          assignee: 'Dyno Nguyen',
          entity: const TicketProviderEntity.gitlabItem(
            projectId: 5,
            assignees: ['Dyno Nguyen'],
            assigneeLogins: ['dyno'],
          ),
        ),
        _t(
          'i1',
          account: _gitlab,
          type: 'Issue',
          assignee: 'Dyno Nguyen',
          entity: const TicketProviderEntity.gitlabItem(
            projectId: 6,
            assigneeLogins: ['someone', 'dyno'],
          ),
        ),
        _t(
          'i2',
          account: _gitlab,
          type: 'Issue',
          assignee: 'Other',
          entity: const TicketProviderEntity.gitlabItem(
            projectId: 6,
            assigneeLogins: ['other'],
          ),
        ),
        _t(
          'pr1',
          account: _github,
          type: 'PullRequest',
          assignee: 'octo',
          entity: const TicketProviderEntity.githubItem(repo: 'o/r'),
        ),
        _t(
          'pr2',
          account: _github,
          type: 'PullRequest',
          assignee: 'Octo Cat',
          entity: const TicketProviderEntity.githubItem(repo: 'o/r'),
          status: UnifiedStatus.done,
          raw: 'merged',
        ),
      ],
      accounts: accounts,
      pinnedProjects: {'gl:5'},
    );
    expect(c.mine('gl'), 1);
    expect(c.project('gl', '5'), 1);
    expect(c.project('gl', '6'), 1);
    expect(c.pinned('gl'), 1);
    expect(c.projects('gl'), 1);
    expect(c.account('gl'), 2);
    expect(c.mine('gh'), 1);
    expect(c.project('gh', 'o/r'), 1);
    expect(c.account('gh'), 1);
    expect(c.workspace('w'), 2);
    expect(c.workspace('w2'), 1);
    expect(c.total, 3);
  });

  test('tickets of unknown accounts are not counted', () {
    final c = count(tickets: [_bug('1', '10')], accounts: const []);
    expect(c.total, 0);
  });
}
