import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import 'ticket_editor_state.dart';

/// Loads, edits and saves the task the editor is open on ([NewTaskRoute] or
/// [EditTaskRoute]).
class TaskEditorController extends AsyncNotifier<TaskEditorState> {
  TaskEditorController(this.route);

  final TicketEditorRoute route;

  @override
  Future<TaskEditorState> build() async {
    final editor = ref.read(zenTaoTicketEditorProvider);
    final res = switch (route) {
      NewTaskRoute(:final executionId, :final parentId) =>
        await editor.newTaskForm(
          route.accountId,
          executionId,
          parentId: parentId,
        ),
      EditTaskRoute(:final taskId) => await editor.editTaskForm(
        route.accountId,
        taskId,
      ),
      _ => throw ArgumentError('Not a task route: $route'),
    };
    return switch (res) {
      Ok(:final value) => TaskEditorState(
        form: value,
        draft: value.draft,
        uid: newFormUid(),
      ),
      Err(:final failure) => throw failure,
    };
  }

  TaskEditorState? get _current => state.asData?.value;

  void edit(TaskDraft Function(TaskDraft draft) change) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(draft: change(current.draft), missing: const {}),
    );
  }

  /// Moves the task to [execution] and reloads its modules, stories and
  /// members.
  Future<void> changeExecution(String execution) async {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        draft: current.draft.copyWith(
          execution: execution,
          module: '0',
          story: '0',
        ),
      ),
    );
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .taskOptions(route.accountId, execution);
    final now = _current;
    if (now == null || res is! Ok<TaskFormOptions>) return;
    state = AsyncData(
      now.copyWith(
        form: now.form.copyWith(
          options: res.value.copyWith(
            executions: res.value.executions.isEmpty
                ? now.form.options.executions
                : res.value.executions,
          ),
        ),
      ),
    );
  }

  Future<String?> uploadImage(Uint8List bytes, String name) async {
    final current = _current;
    if (current == null) return null;
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .uploadImage(route.accountId, current.uid, bytes, name);
    return res is Ok<String> ? res.value : null;
  }

  /// Saves the task; its ticket id, or null when it was not saved.
  Future<String?> save() async {
    final current = _current;
    if (current == null || current.saving) return null;
    final missing = const ValidateTaskDraft()(current.draft);
    if (missing.isNotEmpty) {
      state = AsyncData(current.copyWith(missing: missing));
      return null;
    }
    state = AsyncData(current.copyWith(saving: true, failure: null));
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .saveTask(
          route.accountId,
          current.form,
          current.draft,
          uid: current.uid,
        );
    final now = _current ?? current;
    switch (res) {
      case Ok(:final value):
        state = AsyncData(now.copyWith(saving: false));
        return value;
      case Err(:final failure):
        state = AsyncData(now.copyWith(saving: false, failure: failure));
        return null;
    }
  }
}

final taskEditorProvider = AsyncNotifierProvider.autoDispose
    .family<TaskEditorController, TaskEditorState, TicketEditorRoute>(
      TaskEditorController.new,
    );
