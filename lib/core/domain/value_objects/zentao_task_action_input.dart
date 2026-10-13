import 'package:freezed_annotation/freezed_annotation.dart';

import '../entities/zentao_ticket_form.dart';

part 'zentao_task_action_input.freezed.dart';

/// What a ZenTao task action sends: hours worked this time ([spent]), hours
/// [left], the next [assignee], when work really [began] and [ended], [files]
/// to attach and a [comment]. Each is used only by the actions that ask for
/// it (see `ZenTaoTaskAction`); a null date falls back to the task's own.
@freezed
abstract class ZenTaoTaskActionInput with _$ZenTaoTaskActionInput {
  const factory ZenTaoTaskActionInput({
    @Default(0) double spent,
    @Default(0) double left,
    String? assignee,
    DateTime? began,
    DateTime? ended,
    @Default(<DraftFile>[]) List<DraftFile> files,
    String? comment,
  }) = _ZenTaoTaskActionInput;
}
