import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_entity.freezed.dart';
part 'provider_entity.g.dart';

@freezed
sealed class TicketProviderEntity with _$TicketProviderEntity {
  const factory TicketProviderEntity.zentaoBug({
    String? product,
    String? project,
    String? execution,
    String? branch,
    String? module,
    String? story,
    String? task,
    String? plan,
    String? productName,
    String? projectName,
    String? executionName,
    String? storyTitle,
    String? taskName,
    String? planName,
    String? bugType,
    String? os,
    String? browser,
    int? confirmed,
    int? severity,
    String? resolution,
    String? openedBy,
    DateTime? openedDate,
    String? openedBuild,
    String? assignedTo,
    DateTime? assignedDate,
    String? deadline,
    String? resolvedBy,
    DateTime? resolvedDate,
    String? resolvedBuild,
    String? closedBy,
    DateTime? closedDate,
    String? lastEditedBy,
    DateTime? lastEditedDate,
  }) = ZenTaoBugEntity;

  factory TicketProviderEntity.fromJson(Map<String, dynamic> json) =>
      _$TicketProviderEntityFromJson(json);
}
