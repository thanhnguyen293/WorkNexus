import 'package:freezed_annotation/freezed_annotation.dart';

import '../value_objects/priority.dart';
import '../value_objects/provider_type.dart';
import '../value_objects/unified_status.dart';
import 'provider_entity.dart';

part 'ticket.freezed.dart';

/// The unified ticket — the same shape regardless of source provider.
///
/// [id] is the WorkNexus-local id (stable across syncs); [externalKey] is the
/// provider's own key (e.g. `1092`, `SILVER-142`). [externalType] is the
/// provider object kind where relevant (ZenTao bug/task/story). [providerStatus]
/// keeps the raw status so nothing is lost when normalizing to [status].
/// [sourceHash] is a digest of the translatable content used to detect when a
/// cached translation is outdated.
@freezed
abstract class Ticket with _$Ticket {
  const factory Ticket({
    required String id,
    required String accountId,
    required String projectId,
    required ProviderType providerType,
    required String externalKey,
    required String title,
    required String body,
    required Priority priority,
    required UnifiedStatus status,
    required String providerStatus,
    required String sourceHash,
    String? externalType,
    @Default(<String>[]) List<String> labels,
    String? assignee,
    String? url,
    int? severity,
    DateTime? createdAt,
    DateTime? updatedAt,
    TicketProviderEntity? providerEntity,
  }) = _Ticket;
}
