import 'package:freezed_annotation/freezed_annotation.dart';

part 'zentao_task_action_input.freezed.dart';

/// What a ZenTao task action sends: hours worked this time ([spent]), hours
/// [left], the next [assignee] and a [comment]. Each is used only by the
/// actions that ask for it (see `ZenTaoTaskAction`).
@freezed
abstract class ZenTaoTaskActionInput with _$ZenTaoTaskActionInput {
  const factory ZenTaoTaskActionInput({
    @Default(0) double spent,
    @Default(0) double left,
    String? assignee,
    String? comment,
  }) = _ZenTaoTaskActionInput;
}
