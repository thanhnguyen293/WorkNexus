import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'provider_entity.dart';

part 'zentao_ticket_form.freezed.dart';

/// One choice in a form's select: the value ZenTao stores and its label.
@freezed
abstract class FormOption with _$FormOption {
  const factory FormOption({required String value, required String label}) =
      _FormOption;
}

/// A file picked to attach when the bug or task is saved.
@freezed
abstract class DraftFile with _$DraftFile {
  const factory DraftFile({required String name, required Uint8List bytes}) =
      _DraftFile;
}

/// A ZenTao bug as edited in the form (every field ZenTao's web form has).
/// Ids are ZenTao's, as strings; `'0'` means none.
@freezed
abstract class BugDraft with _$BugDraft {
  const factory BugDraft({
    /// The bug's id when editing; null for a new one.
    String? id,
    required String product,
    @Default('0') String branch,
    @Default('0') String module,
    @Default('0') String project,
    @Default('0') String execution,
    @Default('0') String plan,
    @Default(<String>['trunk']) List<String> openedBuilds,
    @Default('') String assignedTo,
    @Default('') String deadline,
    @Default('codeerror') String type,
    @Default(<String>[]) List<String> os,
    @Default(<String>[]) List<String> browser,
    @Default('') String title,
    @Default('') String color,
    @Default(3) int severity,
    @Default(3) int pri,
    @Default('') String steps,
    @Default('0') String story,
    @Default('0') String task,
    @Default(<String>[]) List<String> mailto,
    @Default('') String keywords,
    @Default(<TicketAttachment>[]) List<TicketAttachment> files,
    @Default(<DraftFile>[]) List<DraftFile> newFiles,
  }) = _BugDraft;
}

/// The choices a bug form offers, as ZenTao lists them for the bug's product
/// (and project / execution).
@freezed
abstract class BugFormOptions with _$BugFormOptions {
  const factory BugFormOptions({
    @Default(<FormOption>[]) List<FormOption> products,
    @Default(<FormOption>[]) List<FormOption> branches,
    @Default(<FormOption>[]) List<FormOption> modules,
    @Default(<FormOption>[]) List<FormOption> projects,
    @Default(<FormOption>[]) List<FormOption> executions,
    @Default(<FormOption>[]) List<FormOption> plans,
    @Default(<FormOption>[]) List<FormOption> builds,
    @Default(<FormOption>[]) List<FormOption> stories,
    @Default(<FormOption>[]) List<FormOption> tasks,
    @Default(<FormOption>[]) List<FormOption> users,
  }) = _BugFormOptions;
}

/// A bug form as loaded: the bug, its choices, and what must be sent back
/// unchanged ([kept]) — ZenTao's edit replaces every field it is not sent.
@freezed
abstract class BugForm with _$BugForm {
  const factory BugForm({
    required BugDraft draft,
    required BugFormOptions options,
    @Default(<String, String>{}) Map<String, String> kept,
  }) = _BugForm;
}

/// A ZenTao task as edited in the form (every field ZenTao's web form has).
@freezed
abstract class TaskDraft with _$TaskDraft {
  const factory TaskDraft({
    /// The task's id when editing; null for a new one.
    String? id,
    required String execution,
    @Default('0') String module,
    @Default('0') String story,
    @Default('0') String parent,
    @Default('') String name,
    @Default('devel') String type,
    @Default(3) int pri,
    @Default(0) double estimate,
    @Default(0) double left,
    @Default(0) double consumed,
    @Default('wait') String status,
    @Default('') String assignedTo,
    @Default('') String estStarted,
    @Default('') String deadline,
    @Default('') String desc,
    @Default('') String color,
    @Default(<String>[]) List<String> mailto,
    @Default('') String keywords,
    @Default(<TicketAttachment>[]) List<TicketAttachment> files,
    @Default(<DraftFile>[]) List<DraftFile> newFiles,
  }) = _TaskDraft;
}

/// The choices a task form offers, as ZenTao lists them for its execution.
@freezed
abstract class TaskFormOptions with _$TaskFormOptions {
  const factory TaskFormOptions({
    @Default(<FormOption>[]) List<FormOption> executions,
    @Default(<FormOption>[]) List<FormOption> modules,
    @Default(<FormOption>[]) List<FormOption> stories,
    @Default(<FormOption>[]) List<FormOption> parents,
    @Default(<FormOption>[]) List<FormOption> users,
  }) = _TaskFormOptions;
}

/// A task form as loaded: the task, its choices, and the fields to send back
/// unchanged ([kept]).
@freezed
abstract class TaskForm with _$TaskForm {
  const factory TaskForm({
    required TaskDraft draft,
    required TaskFormOptions options,
    @Default(<String, String>{}) Map<String, String> kept,
  }) = _TaskForm;
}
