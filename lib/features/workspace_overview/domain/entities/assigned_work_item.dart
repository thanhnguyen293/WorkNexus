import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/value_objects/provider_type.dart';
import '../../../../core/domain/value_objects/unified_status.dart';

part 'assigned_work_item.freezed.dart';

enum AssignedReason { assignee, reviewer }

@freezed
abstract class AssignedWorkItem with _$AssignedWorkItem {
  const factory AssignedWorkItem({
    required String ticketId,
    required ProviderType provider,
    required String displayKey,
    required String title,
    required UnifiedStatus status,
    required String statusLabel,
    required AssignedReason reason,
    DateTime? due,
    DateTime? updatedAt,
  }) = _AssignedWorkItem;
}
