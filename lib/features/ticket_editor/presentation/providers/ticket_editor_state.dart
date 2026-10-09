import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/error/failure.dart';
import '../../domain/usecases/validate_ticket_draft.dart';

part 'ticket_editor_state.freezed.dart';

/// A bug being added or edited: the form as loaded and the draft as changed.
@freezed
abstract class BugEditorState with _$BugEditorState {
  const factory BugEditorState({
    required BugForm form,
    required BugDraft draft,

    /// Ties the images uploaded into the steps to the bug when it is saved.
    required String uid,
    @Default(false) bool saving,
    @Default(<DraftField>{}) Set<DraftField> missing,

    /// Why the last save failed.
    Failure? failure,
  }) = _BugEditorState;
}

/// A task being added or edited.
@freezed
abstract class TaskEditorState with _$TaskEditorState {
  const factory TaskEditorState({
    required TaskForm form,
    required TaskDraft draft,
    required String uid,
    @Default(false) bool saving,
    @Default(<DraftField>{}) Set<DraftField> missing,
    Failure? failure,
  }) = _TaskEditorState;
}

/// A form-session id like ZenTao's own (`uniqid()`-style hex).
String newFormUid() => DateTime.now().microsecondsSinceEpoch.toRadixString(16);
