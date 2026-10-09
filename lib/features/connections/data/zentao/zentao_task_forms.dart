part of 'zentao_ticket_forms.dart';

/// ZenTao's task forms (`task-create` / `task-edit`, and the batch form for a
/// new subtask).
extension ZenTaoTaskForms on ZenTaoTicketForms {
  /// A new task's form in execution [executionId] (`'0'`: ZenTao picks its
  /// current one); a subtask of task [parentId] when given.
  Future<TaskForm> newTask(String executionId, {String? parentId}) async {
    final page = await _page('task-create-$executionId-0-0');
    final legacy = page.containsKey('moduleOptionMenu');
    final task = page['task'] is Map ? page['task'] as Map : const {};
    final options = _taskOptions(page);
    return TaskForm(
      // The create form may not list the parent (18.x lists no parents).
      options:
          parentId == null || options.parents.any((p) => p.value == parentId)
          ? options
          : options.copyWith(
              parents: [
                FormOption(value: parentId, label: '#$parentId'),
                ...options.parents,
              ],
            ),
      kept: {if (legacy) _legacyKey: '1'},
      draft: TaskDraft(
        execution: executionId != '0'
            ? executionId
            : zentaoId(_idOf(page['execution']) ?? task['execution']),
        parent: parentId ?? '0',
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

  /// Saves [draft]; returns the task's ZenTao id (a new subtask's parent's
  /// when ZenTao does not say which id it got).
  Future<String> saveTask(TaskForm form, TaskDraft draft, String uid) async {
    if (draft.id == null && draft.parent != '0') {
      return _saveSubtask(draft, uid);
    }
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

  /// A new subtask, through the batch form. That form takes no attachments,
  /// CC or keywords, so a subtask given any is saved again through its edit
  /// form.
  Future<String> _saveSubtask(TaskDraft draft, String uid) async {
    final res = await _client.classicPost(
      subtaskPath(draft),
      subtaskRow(draft, uid),
    );
    zentaoSaveResult(res.data);
    final id = batchCreatedId(res.data);
    if (id == null) return draft.parent;
    if (draft.newFiles.isNotEmpty ||
        draft.mailto.isNotEmpty ||
        draft.keywords.isNotEmpty) {
      final edit = await editTask(id);
      await saveTask(
        edit,
        edit.draft.copyWith(
          mailto: draft.mailto,
          keywords: draft.keywords,
          newFiles: draft.newFiles,
        ),
        uid,
      );
    }
    return id;
  }
}
