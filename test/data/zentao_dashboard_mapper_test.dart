import 'package:flutter_test/flutter_test.dart';
import 'package:work_nexus/features/dashboard/data/mappers/zentao_dashboard_mapper.dart';
import 'package:work_nexus/features/dashboard/domain/value_objects/dashboard_item_kind.dart';

final _fetchedAt = DateTime(2026, 10, 9, 12);

/// Shaped like a ZenTao 21 `GET /user?fields=…` reply: numbers as strings,
/// one list as an id-keyed object, empty dates as `0000-00-00`.
final _reply = <String, dynamic>{
  'profile': {
    'id': 12,
    'account': 'thanh',
    'realname': 'Thanh Nguyen',
    'role': {'code': 'dev', 'name': 'Developer'},
    'email': 'thanh@example.com',
    'last': '2026-10-09T03:12:00Z',
  },
  'task': {
    'total': '17',
    'tasks': [
      {
        'id': '881',
        'name': 'Build dashboard',
        'status': 'doing',
        'pri': '2',
        'deadline': '2026-10-12',
        'executionName': 'Sprint 42',
      },
      {'name': 'no id — skipped'},
    ],
  },
  'bug': {
    'total': 3,
    'bugs': {
      '4302': {
        'id': 4302,
        'title': 'Crash on login',
        'status': 'active',
        'statusName': 'Active',
        'pri': 1,
        'deadline': '0000-00-00',
        'productName': 'TBChat',
      },
    },
  },
  'todo': {
    'total': 1,
    'todos': [
      {'id': 5, 'name': 'Standup', 'status': 'wait', 'date': '2030-01-01'},
    ],
  },
  'execution': {
    'total': 1,
    'executions': [
      {
        'id': 42,
        'name': 'Sprint 42',
        'projectName': 'TBChat',
        'status': 'doing',
        'hours': {'progress': '62.5'},
        'end': '2026-10-20',
      },
    ],
  },
  'actions': [
    {
      'id': 9001,
      'objectType': 'Bug',
      'objectID': '4302',
      'objectName': 'Crash on login',
      'action': 'resolved',
      'actionLabel': 'resolved',
      'actor': {'account': 'terry', 'realname': 'Terry'},
      'date': '2026-10-09 10:22:11',
    },
  ],
  'contribute': {
    'involvedProjectTotal': '4',
    'ownerProductTotal': 0,
    'docCreatedTotal': 7,
  },
};

void main() {
  final d = zenTaoDashboardFromJson(
    _reply,
    accountId: 'a1',
    fetchedAt: _fetchedAt,
  );

  test('reads the profile, role name included', () {
    expect(d.accountId, 'a1');
    expect(d.fetchedAt, _fetchedAt);
    expect(d.profile.account, 'thanh');
    expect(d.profile.realname, 'Thanh Nguyen');
    expect(d.profile.role, 'Developer');
    expect(d.profile.lastLogin, DateTime.utc(2026, 10, 9, 3, 12));
  });

  test('reads work lists from arrays and id-keyed objects', () {
    expect(d.taskTotal, 17);
    expect(d.tasks, hasLength(1));
    final task = d.tasks.single;
    expect(task.kind, DashboardItemKind.task);
    expect(task.id, '881');
    expect(task.title, 'Build dashboard');
    expect(task.priority, 2);
    expect(task.deadline, DateTime(2026, 10, 12));
    expect(task.context, 'Sprint 42');

    final bug = d.bugs.single;
    expect(bug.id, '4302');
    expect(bug.statusLabel, 'Active');
    expect(bug.deadline, isNull, reason: '0000-00-00 is no date');
    expect(bug.context, 'TBChat');
  });

  test('a future todo has no date', () {
    expect(d.todos.single.kind, DashboardItemKind.todo);
    expect(d.todos.single.deadline, isNull);
  });

  test('reads executions with progress from hours', () {
    final e = d.executions.single;
    expect(e.name, 'Sprint 42');
    expect(e.projectName, 'TBChat');
    expect(e.progress, 62.5);
    expect(d.executionTotal, 1);
  });

  test('reads activity with the actor name and a lower-case type', () {
    final a = d.activities.single;
    expect(a.actor, 'Terry');
    expect(a.action, 'resolved');
    expect(a.objectType, 'bug');
    expect(a.objectId, '4302');
  });

  test('reads contribution counters', () {
    expect(d.projectTotal, 4);
    expect(d.productTotal, 0);
    expect(d.docTotal, 7);
  });

  test('missing blocks become empty lists and null counters', () {
    final bare = zenTaoDashboardFromJson(
      {
        'profile': {'account': 'thanh'},
      },
      accountId: 'a1',
      fetchedAt: _fetchedAt,
    );
    expect(bare.profile.realname, 'thanh');
    expect(bare.stories, isEmpty);
    expect(bare.storyTotal, 0);
    expect(bare.activities, isEmpty);
    expect(bare.projectTotal, isNull);
  });
}
