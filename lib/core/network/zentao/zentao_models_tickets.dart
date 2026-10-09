part of 'zentao_models.dart';

/// A file attached to a ZenTao object (`bug.files[<id>]`).
@JsonSerializable(createToJson: false)
class ZenTaoFile {
  const ZenTaoFile({
    this.id,
    this.title,
    this.name,
    this.extension,
    this.size,
    this.url,
    this.addedBy,
    this.addedDate,
  });

  final Object? id;
  final Object? title;
  final Object? name;
  final Object? extension;
  @JsonKey(fromJson: zentaoInt)
  final int? size;
  final Object? url;
  final Object? addedBy;
  final Object? addedDate;

  factory ZenTaoFile.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoFileFromJson(json);
}

/// One entry in a ticket's action/history collection.
@JsonSerializable(createToJson: false)
class ZenTaoAction {
  const ZenTaoAction({
    this.id,
    this.action,
    this.actor,
    this.comment,
    this.date,
    this.extra,
  });

  final Object? id;
  final Object? action;
  final Object? actor; // String | { account, realname }
  final Object? comment;
  final Object? date;
  final Object? extra; // String | object (assignee / resolution / …)

  factory ZenTaoAction.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoActionFromJson(json);

  String get actionType => action?.toString().toLowerCase() ?? '';
  String get commentText => comment?.toString() ?? '';
}

/// A ZenTao bug / task / story object. Fields differ by kind (title vs name,
/// steps vs desc vs spec) and are read leniently by `normalizeZenTao`.
@JsonSerializable(createToJson: false)
class ZenTaoEntity {
  const ZenTaoEntity({
    this.id,
    this.title,
    this.name,
    this.steps,
    this.desc,
    this.description,
    this.spec,
    this.status,
    this.resolution,
    this.type,
    this.os,
    this.browser,
    this.pri,
    this.confirmed,
    this.severity,
    this.keywords,
    this.assignedTo,
    this.openedBy,
    this.openedDate,
    this.openedBuild,
    this.assignedDate,
    this.deadline,
    this.resolvedBy,
    this.resolvedDate,
    this.resolvedBuild,
    this.closedBy,
    this.closedDate,
    this.lastEditedBy,
    this.lastEditedDate,
    this.productName,
    this.projectName,
    this.executionName,
    this.storyTitle,
    this.taskName,
    this.planName,
    this.product,
    this.project,
    this.execution,
    this.branch,
    this.module,
    this.story,
    this.task,
    this.plan,
    this.activatedCount,
    this.files = const [],
    this.actions = const [],
  });

  final Object? id;
  final Object? title;
  final Object? name;
  final Object? steps;
  final Object? desc;
  final Object? description;
  final Object? spec;
  final Object? status;
  final Object? resolution;
  final Object? type;
  final Object? os;
  final Object? browser;
  @JsonKey(fromJson: zentaoInt)
  final int? pri;
  @JsonKey(fromJson: zentaoInt)
  final int? confirmed;
  @JsonKey(fromJson: zentaoInt)
  final int? severity;
  final Object? keywords;
  final Object? assignedTo; // String | { account, realname }
  final Object? openedBy;
  final Object? openedDate;
  final Object? openedBuild;
  final Object? assignedDate;
  final Object? deadline;
  final Object? resolvedBy;
  final Object? resolvedDate;
  final Object? resolvedBuild;
  final Object? closedBy;
  final Object? closedDate;
  final Object? lastEditedBy;
  final Object? lastEditedDate;
  final Object? productName;
  final Object? projectName;
  final Object? executionName;
  final Object? storyTitle;
  final Object? taskName;
  final Object? planName;
  final Object? product;
  final Object? project;
  final Object? execution;
  final Object? branch;
  final Object? module;
  final Object? story;
  final Object? task;
  final Object? plan;
  @JsonKey(fromJson: zentaoInt)
  final int? activatedCount;
  @JsonKey(fromJson: zentaoFiles)
  final List<ZenTaoFile> files;
  @JsonKey(fromJson: zentaoActions)
  final List<ZenTaoAction> actions;

  factory ZenTaoEntity.fromJson(Map<String, dynamic> json) =>
      _$ZenTaoEntityFromJson(json);

  /// The ZenTao id as a string (`''` when absent).
  String get idString => id?.toString() ?? '';

  /// The first non-empty of the product/project/execution name candidates.
  String get scopeName =>
      (productName ??
              projectName ??
              executionName ??
              product ??
              project ??
              execution ??
              '')
          .toString();
}
