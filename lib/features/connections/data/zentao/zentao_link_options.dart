part of 'zentao_ticket_forms.dart';

/// The bug form's stories and tasks to link, which ZenTao 20+'s form page
/// leaves for its own ajax calls.
extension _LinkOptions on ZenTaoTicketForms {
  /// [options] with the stories and tasks to link filled in. ZenTao 20+'s form
  /// page leaves them out and loads them by ajax — the product's stories, and
  /// the execution's tasks once one is picked — so they are fetched the same
  /// way when the page did not have them. A list that cannot be loaded stays
  /// empty: the rest of the form is still usable.
  Future<BugFormOptions> _withLinkOptions(
    BugFormOptions options, {
    required String productId,
    required String executionId,
  }) async {
    final loadTasks = options.tasks.isEmpty && executionId != '0';
    final (stories, tasks, taskNames) = await (
      options.stories.isEmpty && productId != '0'
          ? _ajaxOptions('story-ajaxGetProductStories-$productId-0-0-0-false')
          : Future.value(options.stories),
      loadTasks
          ? _ajaxOptions('task-ajaxGetExecutionTasks-$executionId')
          : Future.value(options.tasks),
      loadTasks
          ? _taskNames(executionId)
          : Future.value(const <String, String>{}),
    ).wait;
    final people = {for (final user in options.users) user.label};
    return options.copyWith(
      stories: [
        for (final story in stories)
          story.copyWith(label: zentaoLinkLabel(story.label)),
      ],
      tasks: [
        for (final task in tasks)
          task.copyWith(
            label: zentaoTaskLabel(task, taskNames[task.value], people: people),
          ),
      ],
    );
  }

  /// Execution [executionId]'s task names by id, subtasks included. The ajax
  /// list labels a finished task `id:finisher:name`, and a finisher outside
  /// the form's people cannot be told from a colon in the name, so the plain
  /// names come from REST. Empty when REST cannot answer: labels then fall
  /// back to what the ajax list says.
  Future<Map<String, String>> _taskNames(String executionId) async {
    final names = <String, String>{};
    void add(ZenTaoEntity task) {
      final name = zentaoText(task.name);
      if (task.idString.isNotEmpty && name.isNotEmpty) {
        names[task.idString] = name;
      }
      task.children.forEach(add);
    }

    try {
      for (var page = 1; page <= 20; page++) {
        final res = await _client.executionTasks(
          executionId,
          page: page,
          limit: kDefaultApiPageLimit,
        );
        res.tasks.forEach(add);
        if (res.tasks.length < kDefaultApiPageLimit) break;
      }
    } on DioException {
      // Keep what was read; the rest fall back to the ajax labels.
    }
    return names;
  }

  Future<List<FormOption>> _ajaxOptions(String path) async {
    try {
      return zentaoOptions(classicData((await _client.classicGet(path)).data));
    } on DioException {
      return const [];
    }
  }

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
}
