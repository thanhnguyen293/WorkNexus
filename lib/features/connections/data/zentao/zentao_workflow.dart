import 'package:intl/intl.dart';

import '../../../../core/domain/entities/provider_entity.dart';
import '../../../../core/domain/entities/ticket.dart';
import '../../../../core/domain/value_objects/zentao_action.dart';
import '../../../../core/domain/value_objects/zentao_task_action_input.dart';
import 'zentao_action_result.dart';
import 'zentao_client.dart';

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

  /// Runs [action] on [task] with [input].
  Future<void> runTaskAction(
    Ticket task,
    ZenTaoTaskAction action,
    ZenTaoTaskActionInput input,
  ) async {
    final resp = await _client.classicActionPost(
      'task-${action.name}-${task.externalKey}',
      _taskForm(task, action, input),
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
    final comment = _text(input.comment);
    final chosen = _text(input.assignee);
    return switch (action) {
      ZenTaoTaskAction.start || ZenTaoTaskAction.restart => {
        // ZenTao takes the new total logged, not this session's hours.
        'consumed': zentaoHours(logged + input.spent),
        'left': zentaoHours(input.left),
        'realStarted': zentaoDateTime(started ?? now),
        // ZenTao 20+ clears the assignee when the field is missing.
        'assignedTo': chosen ?? _text(task.assignee) ?? _client.account,
        'comment': ?comment,
      },
      ZenTaoTaskAction.finish => {
        'currentConsumed': zentaoHours(input.spent),
        // 18.x reads the new total; 20+ adds currentConsumed itself.
        'consumed': zentaoHours(logged + input.spent),
        'realStarted': zentaoDateTime(started ?? now),
        // ZenTao refuses a finish dated before the start.
        'finishedDate': zentaoDateTime(
          started != null && started.isAfter(now) ? started : now,
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
}

String? _text(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
