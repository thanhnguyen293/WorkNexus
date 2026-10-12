import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/result.dart';
import '../../../../core/navigation/ticket_editor_route.dart';
import '../../domain/entities/saved_ticket_draft.dart';
import '../../domain/usecases/validate_ticket_draft.dart';
import 'ticket_draft_providers.dart';
import 'ticket_editor_state.dart';

/// Loads, edits and saves the task the editor is open on ([NewTaskRoute] or
/// [EditTaskRoute]). A new task is kept as a draft while it is written, and
/// reopens from it ([NewTaskRoute.draftId]).
class TaskEditorController extends AsyncNotifier<TaskEditorState> {
  TaskEditorController(this.route);

  final TicketEditorRoute route;

  late DraftAutosave _autosave;

  @override
  Future<TaskEditorState> build() async {
    final drafts = ref.read(ticketDraftRepositoryProvider);
    final autosave = _autosave = DraftAutosave(drafts);
    // Leaving the editor (Cancel, back, another view) keeps the last change.
    ref.onDispose(() => unawaited(autosave.flush()));
    if (route case NewTaskRoute(:final draftId?)) {
      final kept = await DraftAutosave.read(drafts, draftId);
      if (kept is SavedTaskDraft) return _restore(kept);
    }
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
      Ok(:final value) => _fresh(value),
      Err(:final failure) => throw failure,
    };
  }

  TaskEditorState _fresh(TaskForm form) {
    final uid = newFormUid();
    return TaskEditorState(
      form: form,
      draft: form.draft,
      uid: uid,
      draftId: switch (route) {
        NewTaskRoute(:final draftId) => draftId ?? uid,
        _ => null,
      },
    );
  }

  /// The form of [kept]'s execution (and parent), filled in as the draft was
  /// left.
  Future<TaskEditorState> _restore(SavedTaskDraft kept) async {
    final draft = kept.draft;
    final res = await ref
        .read(zenTaoTicketEditorProvider)
        .newTaskForm(
          route.accountId,
          draft.execution,
          parentId: draft.parent == '0' ? null : draft.parent,
        );
    return switch (res) {
      Ok(:final value) => TaskEditorState(
        form: value,
        draft: draft,
        uid: kept.uid,
        draftId: kept.id,
        draftSavedAt: kept.updatedAt,
      ),
      Err(:final failure) => throw failure,
    };
  }

  /// Keeps the draft once typing pauses — once something was written.
  void _keepDraft() {
    final id = _current?.draftId;
    if (id == null) return;
    _autosave.schedule(
      () {
        final now = _current;
        if (now == null) return null;
        if (now.draftSavedAt == null && now.draft == now.form.draft) {
          return null;
        }
        return SavedTicketDraft.task(
          id: id,
          accountId: route.accountId,
          uid: now.uid,
          updatedAt: DateTime.now(),
          draft: now.draft.copyWith(newFiles: const []),
        );
      },
      onKept: (kept) {
        final now = _current;
        if (!ref.mounted || now == null) return;
        state = AsyncData(switch (kept) {
          Ok(:final value) => now.copyWith(draftSavedAt: value),
          Err(:final failure) => now.copyWith(failure: failure),
        });
      },
    );
  }

  /// Deletes the kept draft; later changes are not kept. False (with the
  /// state's `failure` set) when it could not be deleted, and the editor
  /// stays open.
  Future<bool> discardDraft() async {
    final current = _current;
    final id = current?.draftId;
    if (current == null || id == null) return true;
    final res = await _autosave.discard(id);
    final now = _current ?? current;
    switch (res) {
      case Ok():
        state = AsyncData(now.copyWith(draftId: null, draftSavedAt: null));
        return true;
      case Err(:final failure):
        if (ref.mounted) state = AsyncData(now.copyWith(failure: failure));
        return false;
    }
  }

  TaskEditorState? get _current => state.asData?.value;

  void edit(TaskDraft Function(TaskDraft draft) change) {
    final current = _current;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(draft: change(current.draft), missing: const {}),
    );
    _keepDraft();
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
    _keepDraft();
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
        // In ZenTao now: nothing left to keep, and no later change kept again.
        state = AsyncData(now.copyWith(saving: false, draftId: null));
        if (now.draftId case final id?) await _autosave.discard(id);
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
