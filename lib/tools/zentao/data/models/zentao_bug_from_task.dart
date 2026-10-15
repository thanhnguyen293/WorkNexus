part of 'zentao_ticket_forms.dart';

/// Where a task sits — what a bug reported from it is filed under. Null
/// fields are unknown (or unset), and left to ZenTao.
typedef _TaskScope = ({
  String? product,
  String? project,
  String? execution,
  String? story,
});

extension _BugFromTask on ZenTaoTicketForms {
  /// Task [taskId]'s scope. ZenTao keeps no product on a task, so it is the
  /// execution's — or, when the execution spans several, the story's. When
  /// ZenTao cannot say, the scope is empty and the form opens as before.
  Future<_TaskScope> _taskScope(String taskId, String? executionId) async {
    final task = await _orNull(() => _client.entity('tasks', taskId));
    if (task == null) {
      return (
        product: null,
        project: null,
        execution: executionId,
        story: null,
      );
    }
    final execution = _scopeId(task.execution) ?? executionId;
    final story = _scopeId(task.story);
    return (
      product: await _taskProduct(execution, story),
      project: _scopeId(task.project),
      execution: execution,
      story: story,
    );
  }

  /// The product of a task in [execution] for [story]; null when ZenTao
  /// cannot say. A failed lookup only loses the product, not the rest of the
  /// scope.
  Future<String?> _taskProduct(String? execution, String? story) async {
    final products = execution == null
        ? const <String>[]
        : await _orNull(() => _client.executionProducts(execution)) ??
              const <String>[];
    if (products case [final only]) return only;
    final fromStory = story == null
        ? null
        : _scopeId(
            (await _orNull(() => _client.entity('stories', story)))?.product,
          );
    return fromStory ?? products.firstOrNull;
  }

  String? _scopeId(Object? raw) => switch (zentaoId(raw)) {
    '0' || '' => null,
    final value => value,
  };

  /// [load]'s value, or null when ZenTao cannot answer — a failed request,
  /// or a reply that is not JSON (a sign-in page, a proxy error).
  Future<T?> _orNull<T>(Future<T> Function() load) async {
    try {
      return await load();
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }
}
