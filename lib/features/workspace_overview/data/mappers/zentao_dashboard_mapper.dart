import '../../domain/entities/dashboard_activity.dart';
import '../../domain/entities/dashboard_execution.dart';
import '../../domain/entities/dashboard_profile.dart';
import '../../domain/entities/dashboard_work_item.dart';
import '../../domain/entities/zentao_dashboard.dart';
import '../../domain/value_objects/dashboard_item_kind.dart';

/// The `fields` the dashboard asks `GET /user` for.
const kZenTaoDashboardFields =
    'task,bug,story,todo,execution,actions,contribute';

/// How many items each "my work" list holds.
const kZenTaoDashboardListLimit = 8;

/// Parses a ZenTao `GET /user?fields=…` reply into a [ZenTaoDashboard].
///
/// ZenTao's PHP serialises numbers as strings or ints, lists as arrays or
/// id-keyed maps, and empty dates as `0000-00-00`, and a block is simply absent
/// when the user lacks the privilege — so every field is read leniently and a
/// missing block becomes an empty list.
ZenTaoDashboard zenTaoDashboardFromJson(
  Map<String, dynamic> json, {
  required String accountId,
  required DateTime fetchedAt,
}) {
  final (tasks, taskTotal) = _block(
    json['task'],
    'tasks',
    DashboardItemKind.task,
  );
  final (bugs, bugTotal) = _block(json['bug'], 'bugs', DashboardItemKind.bug);
  final (stories, storyTotal) = _block(
    json['story'],
    'stories',
    DashboardItemKind.story,
  );
  final (todos, todoTotal) = _block(
    json['todo'],
    'todos',
    DashboardItemKind.todo,
  );
  final execution = _map(json['execution']);
  final executions = [
    for (final e in _list(execution?['executions'])) ?_execution(e),
  ];
  final contribute = _map(json['contribute']);
  return ZenTaoDashboard(
    accountId: accountId,
    fetchedAt: fetchedAt,
    profile: _profile(_map(json['profile']) ?? const {}),
    tasks: tasks,
    taskTotal: taskTotal,
    bugs: bugs,
    bugTotal: bugTotal,
    stories: stories,
    storyTotal: storyTotal,
    todos: todos,
    todoTotal: todoTotal,
    executions: executions,
    executionTotal: _int(execution?['total']) ?? executions.length,
    activities: [for (final a in _list(json['actions'])) ?_activity(a)],
    projectTotal: _int(contribute?['involvedProjectTotal']),
    productTotal: _int(contribute?['ownerProductTotal']),
    docTotal: _int(contribute?['docCreatedTotal']),
  );
}

DashboardProfile _profile(Map<String, dynamic> p) {
  final account = _str(p['account']) ?? '';
  final role = p['role'];
  return DashboardProfile(
    account: account,
    realname: _str(p['realname']) ?? account,
    role: role is Map ? _str(role['name']) ?? _str(role['code']) : _str(role),
    email: _str(p['email']),
    lastLogin: _date(p['last']),
  );
}

(List<DashboardWorkItem>, int) _block(
  Object? raw,
  String key,
  DashboardItemKind kind,
) {
  final block = _map(raw);
  final items = [for (final e in _list(block?[key])) ?_item(e, kind)];
  return (items, _int(block?['total']) ?? items.length);
}

DashboardWorkItem? _item(Map<String, dynamic> e, DashboardItemKind kind) {
  final id = _str(e['id']);
  if (id == null) return null;
  return DashboardWorkItem(
    kind: kind,
    id: id,
    title: _str(e['title']) ?? _str(e['name']) ?? '#$id',
    status: _str(e['status'])?.toLowerCase(),
    statusLabel: _str(e['statusName']),
    priority: _int(e['pri']),
    deadline: _date(e['deadline']) ?? _date(e['date']),
    context: _firstStr(e, const [
      'executionName',
      'productName',
      'productTitle',
      'projectName',
    ]),
  );
}

DashboardExecution? _execution(Map<String, dynamic> e) {
  final id = _str(e['id']);
  if (id == null) return null;
  final hours = _map(e['hours']);
  return DashboardExecution(
    id: id,
    name: _str(e['name']) ?? '#$id',
    projectName: _firstStr(e, const ['projectName', 'parentName']),
    status: _str(e['status'])?.toLowerCase(),
    progress: _double(e['progress']) ?? _double(hours?['progress']),
    end: _date(e['end']),
  );
}

DashboardActivity? _activity(Map<String, dynamic> a) {
  final id = _str(a['id']);
  final type = _str(a['objectType']);
  if (id == null || type == null) return null;
  final actor = a['actor'];
  final actorName = actor is Map
      ? _str(actor['realname']) ?? _str(actor['account'])
      : _str(actor);
  return DashboardActivity(
    id: id,
    actor: actorName ?? '',
    action: _str(a['actionLabel']) ?? _str(a['action']) ?? '',
    objectType: type.toLowerCase(),
    objectId: _str(a['objectID']) ?? _str(a['objectId']) ?? '',
    objectName: _str(a['objectName']),
    date: _date(a['date']),
  );
}

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// A JSON array or an id-keyed object, as a list of maps.
Iterable<Map<String, dynamic>> _list(Object? v) {
  final values = switch (v) {
    final List<Object?> list => list,
    final Map<Object?, Object?> map => map.values,
    _ => const <Object?>[],
  };
  return values.whereType<Map<Object?, Object?>>().map(
    Map<String, dynamic>.from,
  );
}

String? _str(Object? v) {
  if (v == null || v is Map || v is List) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String? _firstStr(Map<String, dynamic> e, List<String> keys) {
  for (final k in keys) {
    final s = _str(e[k]);
    if (s != null) return s;
  }
  return null;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse(_str(v) ?? '');

double? _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse(_str(v) ?? '');

/// ZenTao's "no date" is `0000-00-00…`, and a future todo carries `2030-01-01`.
DateTime? _date(Object? v) {
  final s = _str(v);
  if (s == null || s.startsWith('0000') || s.startsWith('2030-01-01')) {
    return null;
  }
  return DateTime.tryParse(s);
}
