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
    String? id(Object? raw) => switch (zentaoId(raw)) {
      '0' || '' => null,
      final value => value,
    };
    try {
      final task = await _client.entity('tasks', taskId);
      final execution = id(task.execution) ?? executionId;
      final story = id(task.story);
      final products = execution == null
          ? const <String>[]
          : await _client.executionProducts(execution);
      final product = switch (products) {
        [final only] => only,
        _ when story != null => id(
          (await _client.entity('stories', story)).product,
        ),
        [final first, ...] => first,
        _ => null,
      };
      return (
        product: product,
        project: id(task.project),
        execution: execution,
        story: story,
      );
    } on DioException {
      return (
        product: null,
        project: null,
        execution: executionId,
        story: null,
      );
    }
  }
}
