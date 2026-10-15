import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_paging.dart';
import '../datasources/zentao_client.dart';
import '../datasources/zentao_form_parsing.dart';
import '../mappers/zentao_normalize.dart';
import 'zentao_models.dart';
import 'zentao_subtask_form.dart';

part 'zentao_bug_from_task.dart';
part 'zentao_link_options.dart';
part 'zentao_task_forms.dart';

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

  /// A new bug's form in product [productId] (`'0'`: ZenTao picks its current
  /// one), filled in by ZenTao from bug [copyOf] (a copy), or filed against
  /// execution [executionId] and task [taskId] — the `extras` its web form
  /// takes in both 18.x and 20+.
  Future<BugForm> newBug(
    String productId, {
    String? copyOf,
    String? executionId,
    String? taskId,
  }) async {
    // ZenTao takes nothing from the task but its id, and with no product it
    // opens its first one, so a bug from a task names the task's own scope.
    final scope = productId == '0' && taskId != null
        ? await _taskScope(taskId, executionId)
        : null;
    if (scope?.product case final scoped?) productId = scoped;
    final extras = [
      if (copyOf != null) 'bugID=$copyOf',
      if (scope?.project case final project?) 'projectID=$project',
      if (scope?.execution ?? executionId case final execution?)
        'executionID=$execution',
      if (taskId != null) 'taskID=$taskId',
      if (scope?.story case final story?) 'storyID=$story',
    ].join(',');
    final page = await _page('bug-create-$productId-0-$extras');
    final legacy = page.containsKey('bugTitle');
    // 20+ keeps the defaults on an init `bug`; 18.x sends them flat.
    final bug = page['bug'] is Map ? page['bug'] as Map : page;
    final product = productId != '0'
        ? productId
        : zentaoId(page['productID'] ?? bug['productID']);
    final execution = zentaoId(
      bug['executionID'] ?? page['executionID'] ?? _idOf(page['execution']),
    );
    return BugForm(
      options: await _withLinkOptions(
        _bugOptions(page),
        productId: product,
        executionId: execution,
      ),
      kept: {if (legacy) _legacyKey: '1'},
      draft: BugDraft(
        product: product,
        module: zentaoId(bug['moduleID'] ?? page['moduleID']),
        project: zentaoId(bug['projectID'] ?? page['projectID']),
        execution: execution,
        story: zentaoId(bug['storyID'] ?? page['storyID']),
        task: zentaoId(bug['taskID'] ?? page['taskID']),
        // A copy keeps its builds; a new bug starts on trunk.
        openedBuilds: switch ([
          for (final build in zentaoCsv(bug['buildID'] ?? page['buildID']))
            if (build != '0') build,
        ]) {
          final builds when builds.isNotEmpty => builds,
          _ => const ['trunk'],
        },
        // 18.x's own `title` is the page's; a copied one is `bugTitle`.
        title: zentaoText(legacy ? page['bugTitle'] : bug['title']),
        type: _or(bug['type'], 'codeerror'),
        severity: zentaoIntOr(bug['severity'], 3),
        pri: zentaoIntOr(bug['pri'], 3),
        // 18.x sends the steps template HTML-escaped.
        steps: zentaoText(bug['steps']),
        assignedTo: zentaoText(bug['assignedTo']),
        deadline: zentaoDate(bug['deadline']),
        os: zentaoCsv(bug['os']),
        browser: zentaoCsv(bug['browser']),
        mailto: zentaoCsv(bug['mailto']),
        keywords: zentaoText(bug['keywords']),
        color: zentaoText(bug['color']),
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
    } else {
      options = await _withLinkOptions(
        options,
        productId: draft.product,
        executionId: draft.execution,
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
  }) async => _withLinkOptions(
    _bugOptions(
      await _page(
        'bug-create-$productId-0-projectID=$projectId,executionID=$executionId',
      ),
    ),
    productId: productId,
    executionId: executionId,
  );

  /// Product [productId]'s bug modules — the form page's list alone, without
  /// the stories and tasks [bugOptions] also loads.
  Future<List<FormOption>> bugModules(String productId) async => _bugOptions(
    await _page('bug-create-$productId-0-projectID=0,executionID=0'),
  ).modules;

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
        for (final field in _keptBugFields) field: ?form.kept[field],
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

/// The id of a ZenTao object given whole (`{id, name…}`), as 18.x gives the
/// current execution.
Object? _idOf(Object? raw) => raw is Map ? raw['id'] : null;

String _or(Object? raw, String fallback) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
