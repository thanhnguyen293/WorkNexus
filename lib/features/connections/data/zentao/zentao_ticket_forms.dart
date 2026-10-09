import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/failure.dart';
import 'zentao_client.dart';
import 'zentao_form_parsing.dart';
import 'zentao_models.dart';
import 'zentao_normalize.dart';

/// Marks, in a form's `kept` fields, that it came from ZenTao 18.x — whose
/// forms differ (field names, which keys it accepts) from 20+.
const _legacyKey = '_legacy';

/// Bug fields an edit must send back unchanged, or ZenTao resets them (and
/// reopens a resolved or closed bug).
const _keptBugFields = [
  'status',
  'resolution',
  'resolvedBy',
  'resolvedDate',
  'resolvedBuild',
  'closedBy',
  'closedDate',
  'duplicateBug',
  'feedbackBy',
  'notifyEmail',
  'testtask',
  'case',
  'lastEditedDate',
];

/// Task fields an edit must send back unchanged.
const _keptTaskFields = [
  'mode',
  'realStarted',
  'finishedBy',
  'finishedDate',
  'canceledBy',
  'canceledDate',
  'closedBy',
  'closedReason',
  'closedDate',
  'lastEditedDate',
];

/// Loads and saves ZenTao's own bug and task forms (its classic web actions:
/// `bug-create` / `bug-edit` / `task-create` / `task-edit`), so what is saved
/// is checked exactly as on the web. See `docs`-level notes in each method for
/// how 18.x and 20+ differ.
class ZenTaoTicketForms {
  const ZenTaoTicketForms(this._client);

  final ZenTaoClient _client;

  Future<Map<String, dynamic>> _page(String path) async {
    final payload = classicPayload((await _client.classicGet(path)).data);
    if (payload == null) {
      throw NotFoundFailure('ZenTao did not return the form ($path)');
    }
    return payload;
  }

  // ---- bugs ----

  Future<BugForm> newBug(String productId) async {
    final page = await _page('bug-create-$productId-0-');
    final legacy = page.containsKey('bugTitle');
    // 20+ keeps the defaults on an init `bug`; 18.x sends them flat.
    final bug = page['bug'] is Map ? page['bug'] as Map : page;
    return BugForm(
      options: _bugOptions(page),
      kept: {if (legacy) _legacyKey: '1'},
      draft: BugDraft(
        product: productId,
        module: zentaoId(bug['moduleID'] ?? page['moduleID']),
        project: zentaoId(page['projectID']),
        execution: zentaoId(page['executionID']),
        type: _or(bug['type'], 'codeerror'),
        severity: zentaoIntOr(bug['severity'], 3),
        pri: zentaoIntOr(bug['pri'], 3),
        // 18.x sends the steps template HTML-escaped.
        steps: zentaoText(bug['steps']),
        assignedTo: zentaoText(bug['assignedTo']),
      ),
    );
  }

  Future<BugForm> editBug(String bugId) async {
    final page = await _page('bug-edit-$bugId');
    final legacy = !page.containsKey('openedBuilds');
    final raw = page['bug'];
    if (raw is! Map) throw NotFoundFailure('ZenTao bug $bugId not found');
    final bug = Map<String, dynamic>.from(raw);
    final draft = BugDraft(
      id: bugId,
      product: zentaoId(bug['product']),
      branch: zentaoId(bug['branch']),
      module: zentaoId(bug['module']),
      project: zentaoId(bug['project']),
      execution: zentaoId(bug['execution']),
      plan: zentaoId(bug['plan']),
      openedBuilds: zentaoCsv(bug['openedBuild']),
      assignedTo: zentaoText(bug['assignedTo']),
      deadline: zentaoDate(bug['deadline']),
      type: _or(bug['type'], 'codeerror'),
      os: zentaoCsv(bug['os']),
      browser: zentaoCsv(bug['browser']),
      title: zentaoText(bug['title']),
      color: zentaoText(bug['color']),
      severity: zentaoIntOr(bug['severity'], 3),
      pri: zentaoIntOr(bug['pri'], 3),
      steps: bug['steps']?.toString() ?? '',
      story: zentaoId(bug['story']),
      task: zentaoId(bug['task']),
      mailto: zentaoCsv(bug['mailto']),
      keywords: zentaoText(bug['keywords']),
      files: zentaoAttachments(ZenTaoEntity.fromJson(bug), _client.baseUrl),
    );
    // 18.x's edit page has no builds or stories: the create page has them.
    var options = _bugOptions(page);
    if (legacy || options.builds.isEmpty) {
      final extra = await bugOptions(
        draft.product,
        projectId: draft.project,
        executionId: draft.execution,
      );
      options = options.copyWith(
        builds: options.builds.isEmpty ? extra.builds : options.builds,
        stories: options.stories.isEmpty ? extra.stories : options.stories,
        tasks: options.tasks.isEmpty ? extra.tasks : options.tasks,
      );
    }
    return BugForm(
      draft: draft,
      options: options,
      kept: {
        for (final field in _keptBugFields) field: '${bug[field] ?? ''}',
        'related': '${bug['relatedBug'] ?? bug['linkBug'] ?? ''}',
        if (legacy) _legacyKey: '1',
      },
    );
  }

  Future<BugFormOptions> bugOptions(
    String productId, {
    String projectId = '0',
    String executionId = '0',
  }) async => _bugOptions(
    await _page(
      'bug-create-$productId-0-projectID=$projectId,executionID=$executionId',
    ),
  );

  BugFormOptions _bugOptions(Map<String, dynamic> page) {
    // 20+ also nests some lists in its init `bug`.
    final bug = page['bug'] is Map ? page['bug'] as Map : const {};
    Object? pick(String key, [String? alt]) =>
        page[key] ?? (alt == null ? null : page[alt]) ?? bug[key];
    return BugFormOptions(
      products: zentaoOptions(pick('products')),
      branches: zentaoOptions(pick('branches', 'branchTagOption')),
      modules: zentaoOptions(pick('moduleOptionMenu', 'modules')),
      projects: zentaoOptions(pick('projects')),
      executions: zentaoOptions(pick('executions')),
      plans: zentaoOptions(pick('plans')),
      builds: zentaoOptions(pick('builds', 'openedBuilds')),
      stories: zentaoOptions(pick('stories')),
      tasks: zentaoOptions(pick('tasks')),
      users: zentaoOptions(pick('assignedToList', 'productMembers')).isEmpty
          ? zentaoOptions(pick('users'))
          : zentaoOptions(pick('assignedToList', 'productMembers')),
    );
  }

  /// Saves [draft]; returns the bug's ZenTao id.
  Future<String> saveBug(BugForm form, BugDraft draft, String uid) async {
    final legacy = form.kept[_legacyKey] == '1';
    final id = draft.id;
    final fields = <String, Object>{
      'uid': uid,
      'product': draft.product,
      'branch': draft.branch,
      'module': draft.module,
      'project': draft.project,
      'execution': draft.execution,
      'plan': draft.plan,
      'openedBuild[]': draft.openedBuilds,
      'assignedTo': draft.assignedTo,
      // An empty date is left out: ZenTao fills in its own "none".
      if (draft.deadline.isNotEmpty) 'deadline': draft.deadline,
      'type': draft.type,
      'os[]': draft.os,
      'browser[]': draft.browser,
      'title': draft.title,
      'color': draft.color,
      'severity': '${draft.severity}',
      'pri': '${draft.pri}',
      'steps': draft.steps,
      'story': draft.story,
      'task': draft.task,
      'mailto[]': draft.mailto,
      'keywords': draft.keywords,
      if (id != null) ...{
        for (final field in _keptBugFields)
          if (form.kept[field] case final value?) field: value,
        if (zentaoCsv(form.kept['related']) case final related
            when related.isNotEmpty)
          legacy ? 'linkBug[]' : 'relatedBug[]': related,
        'deleteFiles[]': _removed(form.draft.files, draft.files),
      },
    };
    final path = id == null
        ? 'bug-create-${draft.product}-${draft.branch}-'
        : 'bug-edit-$id';
    final saved = await _post(path, fields, draft.newFiles);
    return id ?? saved ?? (throw const ParseFailure('ZenTao gave no bug id'));
  }

  // ---- tasks ----

  Future<TaskForm> newTask(String executionId) async {
    final page = await _page('task-create-$executionId-0-0');
    final legacy = page.containsKey('moduleOptionMenu');
    final task = page['task'] is Map ? page['task'] as Map : const {};
    return TaskForm(
      options: _taskOptions(page),
      kept: {if (legacy) _legacyKey: '1'},
      draft: TaskDraft(
        execution: executionId,
        module: zentaoId(task['module']),
        story: zentaoId(task['story']),
        type: _or(task['type'], 'devel'),
        pri: zentaoIntOr(task['pri'], 3),
        assignedTo: zentaoText(task['assignedTo']),
      ),
    );
  }

  Future<TaskForm> editTask(String taskId) async {
    final page = await _page('task-edit-$taskId');
    final legacy = !page.containsKey('parentTask');
    final raw = page['task'];
    if (raw is! Map) throw NotFoundFailure('ZenTao task $taskId not found');
    final task = Map<String, dynamic>.from(raw);
    return TaskForm(
      options: _taskOptions(page),
      kept: {
        for (final field in _keptTaskFields) field: '${task[field] ?? ''}',
        if (legacy) _legacyKey: '1',
      },
      draft: TaskDraft(
        id: taskId,
        execution: zentaoId(task['execution']),
        module: zentaoId(task['module']),
        story: zentaoId(task['story']),
        parent: zentaoId(task['parent']),
        name: zentaoText(task['name']),
        type: _or(task['type'], 'devel'),
        pri: zentaoIntOr(task['pri'], 3),
        estimate: zentaoNumber(task['estimate']),
        left: zentaoNumber(task['left']),
        consumed: zentaoNumber(task['consumed']),
        status: _or(task['status'], 'wait'),
        assignedTo: zentaoText(task['assignedTo']),
        estStarted: zentaoDate(task['estStarted']),
        deadline: zentaoDate(task['deadline']),
        desc: task['desc']?.toString() ?? '',
        color: zentaoText(task['color']),
        mailto: zentaoCsv(task['mailto']),
        keywords: zentaoText(task['keywords']),
        files: zentaoAttachments(ZenTaoEntity.fromJson(task), _client.baseUrl),
      ),
    );
  }

  Future<TaskFormOptions> taskOptions(String executionId) async =>
      _taskOptions(await _page('task-create-$executionId-0-0'));

  TaskFormOptions _taskOptions(Map<String, dynamic> page) {
    final members = zentaoOptions(page['members']);
    return TaskFormOptions(
      executions: zentaoOptions(page['executions']),
      modules: zentaoOptions(
        page['modulePairs'] ?? page['moduleOptionMenu'] ?? page['modules'],
      ),
      stories: zentaoOptions(page['stories']),
      parents: zentaoOptions(page['parents'] ?? page['tasks']),
      users: members.isEmpty ? zentaoOptions(page['users']) : members,
    );
  }

  /// Saves [draft]; returns the task's ZenTao id.
  Future<String> saveTask(TaskForm form, TaskDraft draft, String uid) async {
    final legacy = form.kept[_legacyKey] == '1';
    final id = draft.id;
    String hours(double h) => h == h.roundToDouble() ? '${h.toInt()}' : '$h';
    final fields = <String, Object>{
      'uid': uid,
      'execution': draft.execution,
      'module': draft.module,
      'story': draft.story,
      'name': draft.name,
      'type': draft.type,
      'pri': '${draft.pri}',
      'estimate': hours(draft.estimate),
      if (draft.estStarted.isNotEmpty) 'estStarted': draft.estStarted,
      if (draft.deadline.isNotEmpty) 'deadline': draft.deadline,
      'desc': draft.desc,
      'color': draft.color,
      'mailto[]': draft.mailto,
      // 18.x's task table has no keywords column (an unknown key fails there).
      if (!legacy) 'keywords': draft.keywords,
      if (id == null)
        // 18.x creates nothing without an assignedTo list.
        legacy ? 'assignedTo[]' : 'assignedTo': legacy
            ? [draft.assignedTo]
            : draft.assignedTo
      else ...{
        'assignedTo': draft.assignedTo,
        'parent': draft.parent,
        'status': draft.status,
        'left': hours(draft.left),
        'consumed': hours(draft.consumed),
        for (final field in _keptTaskFields)
          if (form.kept[field] case final value? when value.isNotEmpty)
            field: value,
        'deleteFiles[]': _removed(form.draft.files, draft.files),
      },
    };
    final path = id == null
        ? 'task-create-${draft.execution}-0-0'
        : 'task-edit-$id';
    final saved = await _post(path, fields, draft.newFiles);
    return id ?? saved ?? (throw const ParseFailure('ZenTao gave no task id'));
  }

  // ---- shared ----

  /// Uploads an image for a description; returns the URL to embed it at.
  Future<String> uploadImage(String uid, Uint8List bytes, String name) async {
    final res = await _client.classicPost(
      'file-ajaxUpload-$uid',
      FormData.fromMap({
        'imgFile': MultipartFile.fromBytes(bytes, filename: name),
      }),
    );
    final reply = classicPayload(res.data);
    final url = reply?['url']?.toString() ?? '';
    if (url.isEmpty || '${reply?['error'] ?? 0}' != '0') {
      throw ValidationFailure(
        reply?['message']?.toString() ?? 'ZenTao did not take the image',
      );
    }
    // ZenTao answers a path under its web root.
    if (Uri.tryParse(url)?.hasScheme ?? false) return url;
    return Uri.parse(_client.baseUrl).resolve(url).toString();
  }

  Future<String?> _post(
    String path,
    Map<String, Object> fields,
    List<DraftFile> files,
  ) async {
    final Object data = files.isEmpty
        ? fields
        : FormData.fromMap({
            ...fields,
            'files[]': [
              for (final f in files)
                MultipartFile.fromBytes(f.bytes, filename: f.name),
            ],
            'labels[]': [for (final f in files) f.name],
          });
    return zentaoSaveResult((await _client.classicPost(path, data)).data);
  }
}

/// The ids of the [loaded] attachments no longer in [kept].
List<String> _removed(
  List<TicketAttachment> loaded,
  List<TicketAttachment> kept,
) => [
  for (final f in loaded)
    if (!kept.contains(f)) f.id,
];

String _or(Object? raw, String fallback) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
