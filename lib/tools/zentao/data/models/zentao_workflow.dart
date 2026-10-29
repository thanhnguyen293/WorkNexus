import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/entities/zentao_ticket_form.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/domain/value_objects/zentao_task_action_input.dart';
import '../datasources/zentao_client.dart';
import '../datasources/zentao_form_parsing.dart';
import 'zentao_action_result.dart';

/// Hours as ZenTao's forms take them: `2`, `2.5`.
String zentaoHours(double hours) {
  final rounded = (hours * 100).round() / 100;
  return rounded == rounded.roundToDouble() ? '${rounded.toInt()}' : '$rounded';
}

/// A date-time as ZenTao's forms take it (server-local `yyyy-MM-dd HH:mm:ss`).
String zentaoDateTime(DateTime time) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(time.toLocal());

/// ZenTao's bug and task status actions, through its classic web actions
/// (`bug-close-{id}`, `task-start-{id}`…) with the fields its own forms send.
///
/// Only a form's own fields are sent: ZenTao 18.x writes every posted field to
/// the task row, so an unknown one fails the save.
class ZenTaoWorkflow {
  ZenTaoWorkflow(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ZenTaoClient _client;
  final DateTime Function() _now;

  /// Closes resolved bug [bugId].
  Future<void> closeBug(String bugId, {String? comment}) async {
    final resp = await _client.classicActionPost('bug-close-$bugId', {
      'comment': ?_text(comment),
    });
    ensureZenTaoActionOk(resp, 'close');
  }

  /// Confirms bug [bugId] (ZenTao sets `confirmed = 1`), assigning it to
  /// [assignee].
  ///
  /// ZenTao 20+ names the action `bug-confirm`, 18.x `bug-confirmBug`; the
  /// form page tells which one this server has. 20+ also writes every form
  /// field left out of the POST with its default (priority 3, empty status,
  /// type, deadline and CC list — an empty status is refused), so the bug's
  /// own values go along, as ZenTao's form sends them.
  Future<void> confirmBug(
    String bugId, {
    required String assignee,
    String? comment,
  }) async {
    Future<Map<Object?, Object?>?> form(String action) async =>
        switch (classicPayload((await _client.classicGet(action)).data)) {
          {'bug': final Map<Object?, Object?> bug} => bug,
          _ => null,
        };
    var action = 'bug-confirm-$bugId';
    var bug = await form(action);
    if (bug == null) {
      action = 'bug-confirmBug-$bugId';
      bug = await form(action) ?? const <Object?, Object?>{};
    }
    final deadline = zentaoDate(bug['deadline']);
    final type = zentaoText(bug['type']).trim();
    final status = zentaoText(bug['status']).trim();
    final resp = await _client.classicPost(action, <String, Object>{
      'uid': _client.formUid(),
      'assignedTo': assignee,
      'pri': '${zentaoIntOr(bug['pri'], 3)}',
      // Only an active bug can be confirmed.
      'status': status.isEmpty ? 'active' : status,
      if (type.isNotEmpty) 'type': type,
      if (deadline.isNotEmpty) 'deadline': deadline,
      'mailto[]': zentaoCsv(bug['mailto']),
      'comment': ?_text(comment),
    });
    ensureZenTaoActionOk(resp, 'confirm');
  }

  /// Runs [action] on [task] with [input].
  Future<void> runTaskAction(
    Ticket task,
    ZenTaoTaskAction action,
    ZenTaoTaskActionInput input,
  ) async {
    final fields = {
      'uid': _client.formUid(),
      ..._taskForm(task, action, input),
    };
    final files = action.asksFiles ? input.files : const <DraftFile>[];
    final resp = await _client.classicPost(
      'task-${action.name}-${task.externalKey}',
      files.isEmpty
          ? fields
          : FormData.fromMap({
              ...fields,
              'files[]': [
                for (final f in files)
                  MultipartFile.fromBytes(f.bytes, filename: f.name),
              ],
              'labels[]': [for (final f in files) f.name],
            }),
    );
    ensureZenTaoActionOk(resp, action.name);
  }

  Map<String, String> _taskForm(
    Ticket task,
    ZenTaoTaskAction action,
    ZenTaoTaskActionInput input,
  ) {
    final (logged, started) = switch (task.providerEntity) {
      ZenTaoTaskEntity(:final consumed, :final realStarted) => (
        consumed ?? 0.0,
        realStarted,
      ),
      _ => (0.0, null),
    };
    final now = _now();
    final began = input.began ?? started ?? now;
    final comment = _text(input.comment);
    final chosen = _text(input.assignee);
    return switch (action) {
      ZenTaoTaskAction.start || ZenTaoTaskAction.restart => {
        // ZenTao takes the new total logged, not this session's hours.
        'consumed': zentaoHours(logged + input.spent),
        'left': zentaoHours(input.left),
        'realStarted': zentaoDateTime(began),
        // ZenTao 20+ clears the assignee when the field is missing.
        'assignedTo': chosen ?? _text(task.assignee) ?? _client.account,
        'comment': ?comment,
      },
      ZenTaoTaskAction.finish => {
        'currentConsumed': zentaoHours(input.spent),
        // 18.x reads the new total; 20+ adds currentConsumed itself.
        'consumed': zentaoHours(logged + input.spent),
        'realStarted': zentaoDateTime(began),
        // ZenTao refuses a finish dated before the start.
        'finishedDate': zentaoDateTime(
          input.ended ?? (began.isAfter(now) ? began : now),
        ),
        // Left out, ZenTao hands a finished task back to its creator.
        'assignedTo': ?chosen,
        'comment': ?comment,
      },
      ZenTaoTaskAction.activate => {
        'left': zentaoHours(input.left),
        'assignedTo': chosen ?? _client.account,
        'comment': ?comment,
      },
      ZenTaoTaskAction.pause ||
      ZenTaoTaskAction.close ||
      ZenTaoTaskAction.cancel => {'comment': ?comment},
    };
  }

  /// Deletes task [taskId].
  Future<void> deleteTask(String taskId) async {
    final resp = await _client.deleteTask(taskId);
    ensureZenTaoActionOk(resp, 'delete');
  }
}

String? _text(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
