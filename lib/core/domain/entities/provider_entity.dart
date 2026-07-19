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
    int? activatedCount,
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
    @Default(<TicketAttachment>[]) List<TicketAttachment> attachments,
  }) = ZenTaoBugEntity;

  /// Structured metadata for a GitLab issue or merge request. MR-only fields
  /// (branches, merge status, draft, reviewers) are null on issues.
  const factory TicketProviderEntity.gitlabItem({
    String? projectPath,
    int? projectId,
    String? author,
    String? sourceBranch,
    String? targetBranch,
    String? mergeStatus,
    bool? draft,
    int? upvotes,
    @Default(<String>[]) List<String> reviewers,
    @Default(<String>[]) List<String> assignees,
  }) = GitLabItemEntity;

  factory TicketProviderEntity.fromJson(Map<String, dynamic> json) =>
      _$TicketProviderEntityFromJson(json);
}

/// A file attached to a provider ticket (screenshot, screen recording, log).
///
/// [url] is the provider's authenticated download URL — the bytes are fetched
/// through the account's credentialed client, never opened directly. [size] is
/// in bytes; [extension] is the lowercased file extension without the dot.
@freezed
abstract class TicketAttachment with _$TicketAttachment {
  const factory TicketAttachment({
    required String id,
    required String title,
    required String url,
    String? extension,
    int? size,
    String? addedBy,
    DateTime? addedDate,
  }) = _TicketAttachment;

  factory TicketAttachment.fromJson(Map<String, dynamic> json) =>
      _$TicketAttachmentFromJson(json);
}
