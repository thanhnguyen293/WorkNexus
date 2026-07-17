import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_event.freezed.dart';

/// A provider-side history record (opened, assigned, resolved, commented, …).
@freezed
abstract class ActivityEvent with _$ActivityEvent {
  const factory ActivityEvent({
    required String id,
    required String ticketId,
    required String actor,
    required String action,
    required DateTime at,
    String? detail,
  }) = _ActivityEvent;
}
